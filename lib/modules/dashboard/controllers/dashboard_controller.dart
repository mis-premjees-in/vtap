import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/models/task_model.dart';
import '../../../routes/app_routes.dart';

class DashboardController extends GetxController {
  final ApiService _apiService = ApiService();

  // =========================================================
  // STATES & VARIABLES
  // =========================================================
  RxBool isLoading = false.obs;
  RxBool isPunching = false.obs;
  RxBool isHindi = false.obs;
  RxString currentPunchStatus = "out".obs;
  RxInt highlightedIndex = 0.obs;
  RxList<TaskModel> tasks = <TaskModel>[].obs;
  RxSet<String> completingTasks = <String>{}.obs;
  Rx<TaskModel?> reminderTask = Rx<TaskModel?>(null);

  Timer? highlightTimer;
  Timer? reminderTimer;
  bool autoPunchSnackbarShown = false;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
    startHighlightAnimation();
    startReminderChecker();
  }

  Future<void> loadInitialData() async {
    await loadPunchStatus();
    await Future.delayed(const Duration(milliseconds: 1200));
    await autoPunchInIfInsidePremise();
    await fetchTasks();
  }

  // =========================================================
  // FETCH TASKS (SYNCING MADB & UTEDB)
  // =========================================================
  Future<void> fetchTasks({bool showLoader = true}) async {
    try {
      if (showLoader) isLoading.value = true;
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      // 1. Fetch Master Tasks (MADB)
      final dynamic masterResponse =
          await _apiService.getTasks(username: username);

      // 2. Fetch Completed Tasks (UTEDB - All today's records)
      final dynamic completedResponse =
          await _apiService.getTodayCompletedTasks(username: username);

      final Set<String> todayCompletedMadbIds = {};
      final Map<String, String> utedbHowsMap = {};
      final now = DateTime.now();
      final String todayDateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Frontend Filtering for UTEDB
      List<dynamic> completedRecords = [];
      if (completedResponse is List) {
        completedRecords = completedResponse;
      } else if (completedResponse is Map<String, dynamic> &&
          completedResponse['response']?['Records'] is List) {
        completedRecords = completedResponse['response']['Records'];
      }

      for (final item in completedRecords) {
        String createdDate = item['utedb_created']?.toString() ?? "";
        if (createdDate.startsWith(todayDateStr)) {
          String mid = item['utedb_madb'].toString();
          todayCompletedMadbIds.add(mid);
          if (item['utedb_hows1'] != null) {
            utedbHowsMap[mid] = item['utedb_hows1'].toString();
          }
        }
      }

      // Parse MADB and Merge with UTEDB status
      List<dynamic> masterRecords = [];
      if (masterResponse is List) {
        masterRecords = masterResponse;
      } else if (masterResponse is Map<String, dynamic> &&
          masterResponse['response']?['Records'] is List) {
        masterRecords = masterResponse['response']['Records'];
      }

      List<TaskModel> mergedTasks = [];
      for (final item in masterRecords) {
        try {
          Map<String, dynamic> taskData = Map<String, dynamic>.from(item);
          String tid = taskData['madb_id'].toString();

          bool isDone = todayCompletedMadbIds.contains(tid);
          if (isDone && utedbHowsMap.containsKey(tid)) {
            taskData['utedb_hows1'] = utedbHowsMap[tid];
          }

          final task = TaskModel.fromJson(taskData);
          task.isCompleted = isDone;
          mergedTasks.add(task);
        } catch (e) {
          print("MAPPING ERROR => $e");
        }
      }

      // Sorting and UI Update
      mergedTasks.sort((a, b) =>
          a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1));
      tasks.assignAll(mergedTasks);
      updateReminderTask();
      highlightedIndex.value =
          tasks.indexWhere((e) => !e.isCompleted).clamp(0, tasks.length);
    } catch (e) {
      print("FETCH ERROR => $e");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // COMPLETE TASK LOGIC
  // =========================================================
  Future<void> completeTask(TaskModel task) async {
    try {
      // 1. Strict Attendance Check
      if (currentPunchStatus.value != "in") {
        Get.snackbar(
          "Access Denied",
          "Pehle Assigned Premise me jaakar Punch-In karein!",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          icon: const Icon(Icons.lock_outline, color: Colors.white),
        );
        return;
      }

      // 2. Duplicate Submission Check
      if (task.isCompleted || completingTasks.contains(task.id)) {
        Get.snackbar("Lock", "Task already completed today.",
            backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }

      completingTasks.add(task.id);
      Get.dialog(
          const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange)),
          barrierDismissible: false);

      final username = await StorageService.getUsername();
      final premises = await _apiService.getPremises(username: username);

      // 3. Match Task Premise
      Map<String, dynamic>? matchedPremise = premises.firstWhere(
        (p) => p['premises_id'].toString() == task.premiseId.toString(),
        orElse: () => null,
      );

      if (matchedPremise == null) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar("Error", "Premise location not configured.");
        return;
      }

      // 4. Strict Location Validation
      final isInside = await LocationService.isInsidePremise(matchedPremise);
      if (!isInside) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.defaultDialog(
            title: "📍 Location Error",
            middleText: "Please go to ${matchedPremise['premises_name']}");
        return;
      }

      // 5. Image Proof Handling
      File? imageFile;
      if (task.howrMethod.toLowerCase().contains("upload") ||
          task.howrMethod.toLowerCase().contains("image")) {
        imageFile = await pickImage();
        if (imageFile == null) {
          if (Get.isDialogOpen ?? false) Get.back();
          return;
        }
      }

      // 6. External Form Handling
      if (task.howrUrl.trim().isNotEmpty) {
        await launchUrl(Uri.parse(task.howrUrl.trim()),
            mode: LaunchMode.externalApplication);
        if (Get.isDialogOpen ?? false) Get.back();

        final bool? submitted = await Get.dialog<bool>(
          AlertDialog(
            title: const Text("Form Check"),
            content: const Text("Did you submit the form successfully?"),
            actions: [
              TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text("No")),
              ElevatedButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text("Yes")),
            ],
          ),
        );
        if (submitted != true) return;
        Get.dialog(const Center(child: CircularProgressIndicator()),
            barrierDismissible: false);
      }

      // 7. Final Save to UTEDB
      final response = await _apiService.completeTask(
        username: username,
        madbId: task.id.toString(),
        premiseId: task.premiseId,
        howsJsonString: task.getHowsJsonString, // FIXED: Dynamic Step names
        imageFile: imageFile,
      );

      if (Get.isDialogOpen ?? false) Get.back();

      if (response['status'] == true) {
        // 1. Local Task state update karein taaki Tick turant dikhe
        task.isCompleted = true;

        // 2. Ticks aur score ko UI par refresh karein
        tasks.refresh();
        Get.snackbar("Success", "Task saved successfully",
            backgroundColor: Colors.green, colorText: Colors.white);
        await fetchTasks(showLoader: false);
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      print("TASK ERROR => $e");
    } finally {
      completingTasks.remove(task.id);
    }
  }

  // =========================================================
  // ATTENDANCE & PUNCH ACTION
  // =========================================================
  Future<void> handlePunchAction() async {
    try {
      isPunching.value = true;
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      final String nextType = currentPunchStatus.value == "in" ? "Out" : "In";
      final premises = await _apiService.getPremises(username: username);
      final matchedPremise = await LocationService.getMatchedPremise(premises);

      if (matchedPremise == null) {
        Get.defaultDialog(
            title: "📍 Outside Premise",
            middleText: "Valid location par hona zaruri hai.");
        return;
      }

      final whosId = await StorageService.getWhosId();
      final secureToken = await StorageService.getToken();

      final success = await _apiService.submitPunch(
        username: username,
        accessToken: secureToken,
        type: nextType,
        premiseId: matchedPremise['premises_id'].toString(),
        whosId: whosId,
      );

      if (success) {
        currentPunchStatus.value = nextType.toLowerCase();
        await StorageService.saveAttendance(
          status: nextType.toLowerCase(),
          premiseName: matchedPremise['premises_name'].toString(),
        );
        Get.snackbar("Success", "Punched ${nextType} successfully",
            backgroundColor: nextType == "In" ? Colors.green : Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      print("PUNCH ERROR => $e");
    } finally {
      isPunching.value = false;
    }
  }

  Future<void> autoPunchInIfInsidePremise() async {
    try {
      final username = await StorageService.getUsername();
      if (username.isEmpty || currentPunchStatus.value == "in") return;

      final premises = await _apiService.getPremises(username: username);
      final matchedPremise = await LocationService.getMatchedPremise(premises);
      if (matchedPremise == null) return;

      final whosId = await StorageService.getWhosId();
      final secureToken = await StorageService.getToken();

      final success = await _apiService.submitPunch(
        username: username,
        accessToken: secureToken,
        type: "In",
        premiseId: matchedPremise['premises_id'].toString(),
        whosId: whosId,
      );

      if (success) {
        currentPunchStatus.value = "in";
        await StorageService.saveAttendance(
            status: "in",
            premiseName: matchedPremise['premises_name'].toString());
      }
    } catch (_) {}
  }

  Future<void> loadPunchStatus() async {
    try {
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;
      final status = await _apiService.getLastPunchStatus(username: username);
      currentPunchStatus.value = status.toString().toLowerCase();
    } catch (_) {}
  }

  // =========================================================
  // UTILS
  // =========================================================
  Future<void> logoutUser() async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    await StorageService.clearAll();
    Get.offAllNamed(AppRoutes.login);
  }

  void toggleLanguage() {
    isHindi.toggle();
    tasks.refresh();
  }

  Future<File?> pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 50);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  void startHighlightAnimation() {
    highlightTimer?.cancel();
    highlightTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (tasks.isEmpty) return;
      highlightedIndex.value = (highlightedIndex.value + 1) % tasks.length;
    });
  }

  void startReminderChecker() {
    reminderTimer?.cancel();
    reminderTimer = Timer.periodic(
        const Duration(minutes: 1), (timer) => updateReminderTask());
  }

  void updateReminderTask() => reminderTask.value = getCurrentReminderTask();

  TaskModel? getCurrentReminderTask() {
    try {
      final now = DateTime.now();
      for (final task in tasks) {
        if (task.isCompleted || task.whenTime.isEmpty) continue;
        final split = task.whenTime.split(":");
        final taskTime = DateTime(now.year, now.month, now.day,
            int.parse(split[0]), int.parse(split[1]));
        if (now.difference(taskTime).inMinutes.abs() <= 15) return task;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    highlightTimer?.cancel();
    reminderTimer?.cancel();
    super.onClose();
  }
}
