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
  // FETCH TASKS (COMPARING MADB & UTEDB)
  // =========================================================
  Future<void> fetchTasks({bool showLoader = true}) async {
    try {
      if (showLoader) isLoading.value = true;
      final username = await StorageService.getUsername(); // e.g. "cbsaip 4"
      if (username.isEmpty) return;

      // 1. Fetch MADB (Master Tasks)
      final dynamic masterResponse =
          await _apiService.getTasks(username: username);

      // 2. Fetch UTEDB (All records since customWhere is broken)
      final List<dynamic> allCompletedRecords =
          await _apiService.getTodayCompletedTasks(username: username);

      final Set<String> todayCompletedMadbIds = {};
      final Map<String, String> utedbHowsMap = {};

      final now = DateTime.now();
      // Aaj ki date string (2026-05-23)
      final String todayDateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // ==========================================
      // FRONTEND FILTERING START
      // ==========================================
      for (final item in allCompletedRecords) {
        String createdDate = item['utedb_created']?.toString() ?? "";

        // Filter: Check if date starts with today's date
        if (createdDate.startsWith(todayDateStr)) {
          String mid = item['utedb_madb'].toString();
          todayCompletedMadbIds.add(mid);

          if (item['utedb_hows1'] != null) {
            utedbHowsMap[mid] = item['utedb_hows1'].toString();
          }
        }
      }
      // ==========================================

      // Parse Master Tasks and Compare
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
          String currentMadbId = taskData['madb_id'].toString();

          // Match with our filtered TODAY'S IDs
          bool isDone = todayCompletedMadbIds.contains(currentMadbId);

          if (isDone && utedbHowsMap.containsKey(currentMadbId)) {
            taskData['utedb_hows1'] = utedbHowsMap[currentMadbId];
          }

          final task = TaskModel.fromJson(taskData);
          task.isCompleted = isDone;

          mergedTasks.add(task);
        } catch (e) {
          print("MAPPING ERROR => $e");
        }
      }

      // Sort and Update UI
      mergedTasks.sort((a, b) =>
          a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1));
      tasks.assignAll(mergedTasks);
      updateReminderTask();
      highlightedIndex.value =
          tasks.indexWhere((e) => !e.isCompleted).clamp(0, tasks.length);
    } catch (e) {
      print("FETCH TASK ERROR => $e");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // COMPLETE TASK (WITH DUPLICATE PROTECTION)
  // =========================================================
  Future<void> completeTask(TaskModel task) async {
    try {
      if (task.isCompleted || completingTasks.contains(task.id)) {
        Get.snackbar("Lock", "Task already completed today.");
        return;
      }

      if (currentPunchStatus.value != "in") {
        Get.snackbar("Attendance Required", "Please punch in first",
            backgroundColor: Colors.orange);
        return;
      }

      completingTasks.add(task.id);
      Get.dialog(const Center(child: CircularProgressIndicator()),
          barrierDismissible: false);

      final username = await StorageService.getUsername();
      final premises = await _apiService.getPremises(username: username);

      Map<String, dynamic>? matchedPremise = premises.firstWhere(
        (p) => p['premises_id'].toString() == task.premiseId.toString(),
        orElse: () => null,
      );

      if (matchedPremise == null) {
        if (Get.isDialogOpen ?? false) Get.back();
        return;
      }

      final isInside = await LocationService.isInsidePremise(matchedPremise);
      if (!isInside) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.defaultDialog(
            title: "📍 Location Error",
            middleText: "Outside assigned premise.");
        return;
      }

      File? imageFile;
      if (task.howrMethod.toLowerCase().contains("upload")) {
        imageFile = await pickImage();
        if (imageFile == null) {
          if (Get.isDialogOpen ?? false) Get.back();
          return;
        }
      }

      if (task.howrUrl.trim().isNotEmpty) {
        await launchUrl(Uri.parse(task.howrUrl.trim()),
            mode: LaunchMode.externalApplication);
        if (Get.isDialogOpen ?? false) Get.back();
        final bool? submitted = await Get.dialog<bool>(
          AlertDialog(
            title: const Text("Form Check"),
            content: const Text("Did you submit the form?"),
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

      // Final save to UTEDB
      final response = await _apiService.completeTask(
        username: username,
        madbId: task.id.toString(),
        premiseId: task.premiseId,
        howsJsonString: task.getHowsJsonString,
        imageFile: imageFile,
      );

      if (Get.isDialogOpen ?? false) Get.back();

      if (response['status'] == true) {
        Get.snackbar("Success", "Task saved to UTEDB",
            backgroundColor: Colors.green, colorText: Colors.white);
        await fetchTasks(showLoader: false);
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
    } finally {
      completingTasks.remove(task.id);
    }
  }

  // --- Helpers (Punch, Logout, Timers) ---
  Future<void> handlePunchAction() async {
    try {
      isPunching.value = true;
      final username = await StorageService.getUsername();
      final nextType = currentPunchStatus.value == "in" ? "Out" : "In";
      final premises = await _apiService.getPremises(username: username);
      final matchedPremise = await LocationService.getMatchedPremise(premises);
      if (matchedPremise == null) return;
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
            premiseName: matchedPremise['premises_name'].toString());
      }
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

  Future<void> logoutUser() async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    await StorageService.clearAll();
    Get.offAllNamed(AppRoutes.login);
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

  Future<File?> pickImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 50);
    return file != null ? File(file.path) : null;
  }

  void toggleLanguage() {
    isHindi.toggle();
    tasks.refresh();
  }

  @override
  void onClose() {
    highlightTimer?.cancel();
    reminderTimer?.cancel();
    super.onClose();
  }
}
