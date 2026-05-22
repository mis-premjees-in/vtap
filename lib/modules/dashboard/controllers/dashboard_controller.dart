// modules/dashboard/controllers/dashboard_controller.dart

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

class DashboardController extends GetxController {
  final ApiService _apiService = ApiService();

  // =========================================================
  // STATES
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

  // =========================================================
  // INIT
  // =========================================================
  @override
  void onInit() {
    super.onInit();
    loadInitialData();
    startHighlightAnimation();
    startReminderChecker();
  }

  // =========================================================
  // LOAD INITIAL DATA
  // =========================================================
  Future<void> loadInitialData() async {
    await loadPunchStatus();
    await Future.delayed(const Duration(milliseconds: 1200));
    await autoPunchInIfInsidePremise();
    await fetchTasks();
  }

  // =========================================================
  // AUTO PUNCH
  // =========================================================
  Future<void> autoPunchInIfInsidePremise() async {
    try {
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      if (currentPunchStatus.value == "in") {
        if (!autoPunchSnackbarShown) {
          autoPunchSnackbarShown = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            Get.snackbar(
              "🟢 Already Punched In",
              "Attendance already marked",
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              margin: const EdgeInsets.all(12),
              borderRadius: 14,
              duration: const Duration(seconds: 3),
            );
          });
        }
        return;
      }

      final premises = await _apiService.getPremises(username: username);
      if (premises.isEmpty) return;

      final matchedPremise = await LocationService.getMatchedPremise(premises);
      if (matchedPremise == null) return;

      final whosId = await StorageService.getWhosId();
      final secureToken = await StorageService
          .getToken(); // FIXED: Fetched missing secure token from local memory

      // FIXED: Swapped repository object to local uniform _apiService instance channel
      final success = await _apiService.submitPunch(
        username: username,
        accessToken: secureToken,
        type: "In",
        premiseId: matchedPremise['premises_id'].toString(),
        whosId: whosId,
      );

      print("AUTO PUNCH SUCCESS => $success");

      if (success) {
        currentPunchStatus.value = "in";
        await StorageService.saveAttendance(
          status: "in",
          premiseName: matchedPremise['premises_name'].toString(),
        );

        Future.delayed(const Duration(milliseconds: 600), () {
          Get.snackbar(
            "🎉 Auto Punched In",
            "Attendance marked at ${matchedPremise['premises_name']}",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            borderRadius: 14,
            duration: const Duration(seconds: 4),
          );
        });
      }
    } catch (e) {
      print("AUTO PUNCH ERROR => $e");
    }
  }

  // =========================================================
  // LOAD PUNCH STATUS
  // =========================================================
  Future<void> loadPunchStatus() async {
    try {
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      final status = await _apiService.getLastPunchStatus(username: username);
      currentPunchStatus.value = status.toString().toLowerCase();
    } catch (e) {
      print("PUNCH STATUS ERROR => $e");
    }
  }

  // =========================================================
  // FETCH TASKS
  // =========================================================
  Future<void> fetchTasks({bool showLoader = true}) async {
    try {
      if (showLoader) {
        isLoading.value = true;
      }

      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      final dynamic response = await _apiService.getTasks(username: username);
      final dynamic completedResponse =
          await _apiService.getTodayCompletedTasks(username: username);

      List<dynamic> completedRecords = [];
      if (completedResponse is List) {
        completedRecords = completedResponse;
      } else if (completedResponse is Map<String, dynamic>) {
        if (completedResponse['data'] is List) {
          completedRecords = completedResponse['data'];
        }
      }

      final Set<String> completedIds = {};
      final now = DateTime.now();

      for (final item in completedRecords) {
        try {
          final created = DateTime.tryParse(item['utedb_created'].toString());
          if (created == null) continue;

          final isToday = created.year == now.year &&
              created.month == now.month &&
              created.day == now.day;

          if (isToday) {
            completedIds.add(item['utedb_madb'].toString());
          }
        } catch (_) {}
      }

      List<dynamic> records = [];
      if (response is List) {
        records = response;
      } else if (response is Map<String, dynamic>) {
        if (response['response'] is Map<String, dynamic>) {
          final nested = response['response'];
          if (nested['Records'] is List) {
            records = nested['Records'];
          }
        }
      }

      List<TaskModel> fetchedTasks = [];
      for (final item in records) {
        try {
          final task = TaskModel.fromJson(Map<String, dynamic>.from(item));
          if (completedIds.contains(task.id.toString())) {
            task.isCompleted = true;
          }
          fetchedTasks.add(task);
        } catch (e) {
          print("TASK PARSE ERROR => $e");
        }
      }

      fetchedTasks.sort((a, b) {
        if (a.isCompleted == b.isCompleted) return 0;
        return a.isCompleted ? 1 : -1;
      });

      tasks.assignAll(fetchedTasks);
      updateReminderTask();

      highlightedIndex.value = tasks.indexWhere((e) => !e.isCompleted);
      if (highlightedIndex.value < 0) {
        highlightedIndex.value = 0;
      }
    } catch (e) {
      print("FETCH TASK ERROR => $e");
      Get.snackbar(
        "Error",
        "Failed to load tasks",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // LANGUAGE
  // =========================================================
  void toggleLanguage() {
    isHindi.toggle();
    update();
  }

  // =========================================================
  // REMINDER POPUP
  // =========================================================
  void startReminderChecker() {
    reminderTimer?.cancel();
    reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      updateReminderTask();
    });
    updateReminderTask();
  }

  void updateReminderTask() {
    reminderTask.value = getCurrentReminderTask();
  }

  TaskModel? getCurrentReminderTask() {
    try {
      final now = DateTime.now();
      for (final task in tasks) {
        if (task.isCompleted) continue;

        final time = task.whenTime;
        if (time.isEmpty) continue;

        final split = time.split(":");
        if (split.length < 2) continue;

        final hour = int.tryParse(split[0]) ?? 0;
        final minute = int.tryParse(split[1]) ?? 0;

        final taskDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        final diff = now.difference(taskDateTime).inMinutes.abs();
        if (diff <= 15) {
          return task;
        }
      }
      return null;
    } catch (e) {
      print("REMINDER ERROR => $e");
      return null;
    }
  }

  // =========================================================
  // PUNCH ACTION
  // =========================================================
  Future<void> handlePunchAction() async {
    try {
      isPunching.value = true;
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      final nextType = currentPunchStatus.value == "in" ? "Out" : "In";
      final premises = await _apiService.getPremises(username: username);
      final matchedPremise = await LocationService.getMatchedPremise(premises);

      if (matchedPremise == null) {
        Get.defaultDialog(
          title: "📍 Outside Premise",
          middleText: "You are outside allowed location",
        );
        return;
      }

      final whosId = await StorageService.getWhosId();
      final secureToken = await StorageService
          .getToken(); // FIXED: Added secureToken logic pass requirement

      final success = await _apiService.submitPunch(
        username: username,
        accessToken: secureToken, // FIXED: Added missing parameter key value
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

        Get.snackbar(
          "Success",
          nextType == "In"
              ? "Punched In Successfully"
              : "Punched Out Successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print("PUNCH ERROR => $e");
    } finally {
      isPunching.value = false;
    }
  }

  // =========================================================
  // COMPLETE TASK
  // =========================================================
  Future<void> completeTask(TaskModel task) async {
    try {
      if (task.isCompleted || completingTasks.contains(task.id)) return;
      completingTasks.add(task.id);

      if (currentPunchStatus.value != "in") {
        Get.snackbar(
          "Punch Required",
          "Please punch in first",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final username = await StorageService.getUsername();
      final premises = await _apiService.getPremises(username: username);

      Map<String, dynamic>? matchedPremise;
      for (final premise in premises) {
        if (premise['premises_id'].toString() == task.premiseId.toString()) {
          matchedPremise = Map<String, dynamic>.from(premise);
          break;
        }
      }

      if (matchedPremise == null) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar(
          "Error",
          "Assigned premise not found",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final isInside = await LocationService.isInsidePremise(matchedPremise);
      if (!isInside) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.defaultDialog(
          title: "📍 Outside Premise",
          middleText:
              "You are outside assigned location (${matchedPremise['premises_name']})",
        );
        return;
      }

      File? imageFile;
      if (task.howrMethod.toLowerCase().contains("upload") ||
          task.howrMethod.toLowerCase().contains("image")) {
        imageFile = await pickImage();
        if (imageFile == null) {
          if (Get.isDialogOpen ?? false) Get.back();
          return;
        }
      }

      if (task.howrUrl.trim().isNotEmpty) {
        try {
          final String cleanUrl = task.howrUrl.trim();
          final Uri uri = Uri.parse(cleanUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (Get.isDialogOpen ?? false) Get.back();

          final bool? submitted = await Get.dialog<bool>(
            AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text("Form Submission"),
              content:
                  const Text("Did you submit the Google Form successfully?"),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text("No"),
                ),
                ElevatedButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text("Yes"),
                ),
              ],
            ),
          );

          if (submitted != true) return;

          Get.dialog(
            const Center(child: CircularProgressIndicator()),
            barrierDismissible: false,
          );
        } catch (e) {
          print("FORM OPEN ERROR => $e");
        }
      }

      final response = await _apiService.completeTask(
        username: username,
        madbId: task.id.toString(),
        premiseId: matchedPremise['premises_id'].toString(),
        imageFile: imageFile,
      );

      if (Get.isDialogOpen ?? false) Get.back();

      if (response['status'] == true || response['success'] == true) {
        task.isCompleted = true;
        tasks.refresh();
        updateReminderTask();

        Get.snackbar(
          "✅ Task Completed",
          "Task updated successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print("COMPLETE TASK ERROR => $e");
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        "Error",
        "Failed to complete task",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      completingTasks.remove(task.id);
    }
  }

  // =========================================================
  // PICK IMAGE
  // =========================================================
  Future<File?> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
      );
      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      return null;
    }
  }

  // =========================================================
  // HIGHLIGHT
  // =========================================================
  void startHighlightAnimation() {
    highlightTimer?.cancel();
    highlightTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (tasks.isEmpty) return;
      highlightedIndex.value++;
      if (highlightedIndex.value >= tasks.length) {
        highlightedIndex.value = 0;
      }
    });
  }

  @override
  void onClose() {
    highlightTimer?.cancel();
    reminderTimer?.cancel();
    super.onClose();
  }
}
