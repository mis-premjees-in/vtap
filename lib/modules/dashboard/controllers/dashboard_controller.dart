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

  // =====================================================
  // STATES
  // =====================================================

  RxBool isLoading = false.obs;

  RxBool isPunching = false.obs;

  RxBool isHindi = false.obs;

  RxString currentPunchStatus = "out".obs;

  RxInt highlightedIndex = 0.obs;

  RxList<TaskModel> tasks = <TaskModel>[].obs;

  RxSet<String> completingTasks = <String>{}.obs;

  Timer? highlightTimer;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void onInit() {
    super.onInit();

    loadInitialData();

    startHighlightAnimation();
  }

  // =====================================================
  // LOAD INITIAL DATA
  // =====================================================

  Future<void> loadInitialData() async {
    await loadPunchStatus();

    Future.delayed(
      const Duration(milliseconds: 800),
      () async {
        await autoPunchInIfInsidePremise();
      },
    );

    await fetchTasks();
  }

  // =====================================================
  // AUTO PUNCH
  // =====================================================

  Future<void> autoPunchInIfInsidePremise() async {
    try {
      final username = await StorageService.getUsername();

      if (username.isEmpty) {
        return;
      }

      if (currentPunchStatus.value == "in") {
        return;
      }

      final premises = await _apiService.getPremises(
        username: username,
      );

      if (premises.isEmpty) {
        return;
      }

      final matchedPremise = await LocationService.getMatchedPremise(
        premises,
      );

      if (matchedPremise == null) {
        return;
      }

      final whosId = await StorageService.getWhosId();

      final success = await _apiService.submitPunch(
        username: username,
        type: "In",
        premiseId: matchedPremise['premises_id'].toString(),
        whosId: whosId,
      );

      if (success) {
        currentPunchStatus.value = "in";

        await StorageService.saveAttendance(
          status: "in",
          premiseName: matchedPremise['premises_name'].toString(),
        );

        Get.snackbar(
          "🎉 Auto Punch In",
          "Attendance marked successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print("AUTO PUNCH ERROR => $e");
    }
  }

  // =====================================================
  // LOAD PUNCH STATUS
  // =====================================================

  Future<void> loadPunchStatus() async {
    try {
      final username = await StorageService.getUsername();

      if (username.isEmpty) {
        return;
      }

      final status = await _apiService.getLastPunchStatus(
        username: username,
      );

      currentPunchStatus.value = status.toString().toLowerCase();
    } catch (e) {
      print("PUNCH STATUS ERROR => $e");
    }
  }

  // =====================================================
  // FETCH TASKS
  // =====================================================

  Future<void> fetchTasks({
    bool showLoader = true,
  }) async {
    try {
      if (showLoader) {
        isLoading.value = true;
      }

      final username = await StorageService.getUsername();

      if (username.isEmpty) {
        return;
      }

      final dynamic response = await _apiService.getTasks(
        username: username,
      );

      final dynamic completedResponse =
          await _apiService.getTodayCompletedTasks(
        username: username,
      );

      // =====================================================
      // COMPLETED TASK IDS
      // =====================================================

      List<dynamic> completedRecords = [];

      if (completedResponse is List) {
        completedRecords = completedResponse;
      } else if (completedResponse is Map<String, dynamic>) {
        if (completedResponse['data'] is List) {
          completedRecords = completedResponse['data'];
        }
      }

      final now = DateTime.now();

      final Set<String> completedIds = {};

      for (final e in completedRecords) {
        try {
          if (e is Map<String, dynamic>) {
            final created = DateTime.tryParse(
              e['utedb_created'].toString(),
            );

            if (created == null) continue;

            final isToday = created.year == now.year &&
                created.month == now.month &&
                created.day == now.day;

            if (isToday) {
              completedIds.add(
                e['utedb_madb'].toString(),
              );
            }
          }
        } catch (_) {}
      }

      // =====================================================
      // TASK RECORDS
      // =====================================================

      List<dynamic> records = [];

      if (response is List) {
        records = response;
      } else if (response is Map<String, dynamic>) {
        if (response['response'] is Map<String, dynamic>) {
          final nested = response['response'];

          if (nested['Records'] is List) {
            records = nested['Records'];
          }
        } else if (response['Records'] is List) {
          records = response['Records'];
        }
      }

      // =====================================================
      // CREATE TASKS
      // =====================================================

      List<TaskModel> fetchedTasks = [];

      for (final item in records) {
        try {
          final task = TaskModel.fromJson(
            Map<String, dynamic>.from(item),
          );

          if (completedIds.contains(task.id.toString())) {
            task.isCompleted = true;
          }

          fetchedTasks.add(task);
        } catch (e) {
          print("TASK PARSE ERROR => $e");
        }
      }

      // =====================================================
      // SORT TASKS
      // =====================================================

      fetchedTasks.sort((a, b) {
        if (a.isCompleted == b.isCompleted) {
          return 0;
        }

        return a.isCompleted ? 1 : -1;
      });

      tasks.assignAll(fetchedTasks);

      highlightedIndex.value = tasks.indexWhere(
        (task) => !task.isCompleted,
      );

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
      if (showLoader) {
        isLoading.value = false;
      }
    }
  }

  // =====================================================
  // LANGUAGE
  // =====================================================

  void toggleLanguage() {
    isHindi.value = !isHindi.value;
  }

  // =====================================================
  // GET CURRENT REMINDER TASK
  // =====================================================

  TaskModel? getCurrentReminderTask() {
    try {
      final now = TimeOfDay.now();

      for (final task in tasks) {
        if (task.isCompleted) continue;

        final parts = task.whenTime.split(":");

        if (parts.length < 2) continue;

        final hour = int.tryParse(parts[0]) ?? 0;

        final minute = int.tryParse(parts[1]) ?? 0;

        if (hour == now.hour && (now.minute - minute).abs() <= 15) {
          return task;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // =====================================================
  // PUNCH ACTION
  // =====================================================

  Future<void> handlePunchAction() async {
    try {
      isPunching.value = true;

      final username = await StorageService.getUsername();

      if (username.isEmpty) {
        return;
      }

      final nextType = currentPunchStatus.value == "in" ? "Out" : "In";

      final premises = await _apiService.getPremises(
        username: username,
      );

      if (premises.isEmpty) {
        Get.snackbar(
          "Error",
          "No premises assigned",
          snackPosition: SnackPosition.TOP,
        );

        return;
      }

      final matchedPremise = await LocationService.getMatchedPremise(
        premises,
      );

      if (matchedPremise == null) {
        Get.defaultDialog(
          title: "📍 Outside Premise",
          middleText: "You are outside allowed location",
        );

        return;
      }

      final whosId = await StorageService.getWhosId();

      final success = await _apiService.submitPunch(
        username: username,
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

  // =====================================================
  // COMPLETE TASK
  // =====================================================

  Future<void> completeTask(
    TaskModel task,
  ) async {
    try {
      if (task.isCompleted || completingTasks.contains(task.id)) {
        return;
      }

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
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      final username = await StorageService.getUsername();

      final premises = await _apiService.getPremises(
        username: username,
      );

      Map<String, dynamic>? matchedPremise;

// find assigned premise ONLY
      for (final premise in premises) {
        if (premise['premises_id'].toString() == task.premiseId.toString()) {
          matchedPremise = Map<String, dynamic>.from(premise);

          break;
        }
      }

// premise not found
      if (matchedPremise == null) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        Get.snackbar(
          "Error",
          "Assigned premise not found",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        return;
      }

// validate ONLY assigned premise
      final isInside = await LocationService.isInsidePremise(
        matchedPremise,
      );

      if (!isInside) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        Get.defaultDialog(
          title: "📍 Outside Premise",
          middleText:
              "You are outside assigned location (${matchedPremise['premises_name']})",
        );

        return;
      }

      // IMAGE TASK

      File? imageFile;

      if (task.howrMethod.toLowerCase().contains("upload") ||
          task.howrMethod.toLowerCase().contains("image")) {
        imageFile = await pickImage();

        if (imageFile == null) {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }

          return;
        }
      }

      // FORM TASK

      if (task.howrType.toLowerCase().contains("form") &&
          task.howrUrl.isNotEmpty) {
        final Uri uri = Uri.parse(task.howrUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppBrowserView,
          );
        }
      }

      final response = await _apiService.completeTask(
        username: username,
        madbId: task.id.toString(),
        premiseId: matchedPremise['premises_id'].toString(),
      );

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if ((response['status'] == true || response['success'] == true)) {
        task.isCompleted = true;

        tasks.refresh();

        tasks.sort((a, b) {
          if (a.isCompleted == b.isCompleted) {
            return 0;
          }

          return a.isCompleted ? 1 : -1;
        });

        tasks.refresh();

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

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

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

  // =====================================================
  // PICK IMAGE
  // =====================================================

  Future<File?> pickImage() async {
    try {
      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
      );

      if (pickedFile == null) {
        return null;
      }

      return File(pickedFile.path);
    } catch (e) {
      return null;
    }
  }

  // =====================================================
  // HIGHLIGHT
  // =====================================================

  void startHighlightAnimation() {
    highlightTimer?.cancel();

    highlightTimer = Timer.periodic(
      const Duration(seconds: 4),
      (timer) {
        if (tasks.isEmpty) return;

        final pendingTasks = tasks.where((e) => !e.isCompleted).toList();

        if (pendingTasks.isEmpty) {
          highlightedIndex.value = 0;
          return;
        }

        highlightedIndex.value++;

        if (highlightedIndex.value >= pendingTasks.length) {
          highlightedIndex.value = 0;
        }
      },
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void onClose() {
    highlightTimer?.cancel();

    super.onClose();
  }
}
