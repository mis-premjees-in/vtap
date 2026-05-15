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

  RxBool isCarousel = false.obs;

  RxString currentPunchStatus = "out".obs;

  RxInt highlightedIndex = 0.obs;

  RxList<TaskModel> tasks = <TaskModel>[].obs;

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

    await autoPunchInIfInsidePremise();

    await fetchTasks();
  }

  // =====================================================
  // AUTO PUNCH
  // =====================================================

  Future<void> autoPunchInIfInsidePremise() async {
    try {
      final username = await StorageService.getUsername();

      if (username == null || username.isEmpty) {
        return;
      }

      // already punched in
      if (currentPunchStatus.value == "in") {
        return;
      }

      final premises = await _apiService.getPremises(
        username: username,
      );

      if (premises.isEmpty) {
        return;
      }

      final isInside = await LocationService.validateUserInPremise(
        premises,
      );

      if (!isInside) {
        return;
      }

      final success = await _apiService.submitPunch(
        username: username,
        type: "In",
      );

      if (success) {
        currentPunchStatus.value = "in";

        Get.snackbar(
          "🎉 Auto Punch In",
          "Attendance marked successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 14,
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

      if (username == null || username.isEmpty) {
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

      if (username == null || username.isEmpty) {
        return;
      }

      // =========================================
      // GET TASKS RESPONSE
      // =========================================

      final dynamic response = await _apiService.getTasks(
        username: username,
      );

      // =========================================
      // GET COMPLETED TASKS
      // =========================================

      final dynamic completedResponse =
          await _apiService.getTodayCompletedTasks(
        username: username,
      );

      // =========================================
      // PARSE COMPLETED RECORDS
      // =========================================

      List<dynamic> completedRecords = [];

      if (completedResponse is List) {
        completedRecords = completedResponse;
      } else if (completedResponse is Map<String, dynamic>) {
        if (completedResponse['data'] is List) {
          completedRecords = completedResponse['data'];
        }
      }

      // =========================================
      // COMPLETED IDS
      // =========================================

      final Set<String> completedIds = completedRecords.map<String>((e) {
        if (e is Map<String, dynamic>) {
          return e['utedb_madb'].toString();
        }

        return "";
      }).toSet();

      // =========================================
      // PARSE TASK RECORDS
      // =========================================

      List<dynamic> records = [];

      // CASE 1 => DIRECT LIST
      if (response is List) {
        records = response;
      }

      // CASE 2 => MAP RESPONSE
      else if (response is Map<String, dynamic>) {
        // response -> response -> Records
        if (response['response'] is Map<String, dynamic>) {
          final nestedResponse = response['response'] as Map<String, dynamic>;

          if (nestedResponse['Records'] is List) {
            records = nestedResponse['Records'];
          }
        }

        // response -> Records
        else if (response['Records'] is List) {
          records = response['Records'];
        }

        // response -> data
        else if (response['data'] is List) {
          records = response['data'];
        }
      }

      // =========================================
      // CREATE TASK MODELS
      // =========================================

      List<TaskModel> fetchedTasks = [];

      for (final item in records) {
        try {
          if (item is Map<String, dynamic>) {
            final task = TaskModel.fromJson(item);

            // completed check
            if (completedIds.contains(task.id.toString())) {
              task.isCompleted = true;
            }

            fetchedTasks.add(task);
          } else if (item is Map) {
            final task = TaskModel.fromJson(
              Map<String, dynamic>.from(item),
            );

            if (completedIds.contains(task.id.toString())) {
              task.isCompleted = true;
            }

            fetchedTasks.add(task);
          }
        } catch (e) {
          print("TASK PARSE ERROR => $e");
        }
      }

      // =========================================
      // SORT TASKS
      // =========================================

      fetchedTasks.sort((a, b) {
        if (a.isCompleted == b.isCompleted) {
          return 0;
        }

        return a.isCompleted ? 1 : -1;
      });

      tasks.assignAll(fetchedTasks);

      // =========================================
      // HIGHLIGHT INDEX
      // =========================================

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
  // TOGGLE LANGUAGE
  // =====================================================

  void toggleLanguage() {
    isHindi.value = !isHindi.value;
  }

  // =====================================================
  // MANUAL PUNCH
  // =====================================================

  Future<void> handlePunchAction() async {
    try {
      isPunching.value = true;

      final username = await StorageService.getUsername();

      if (username == null || username.isEmpty) {
        return;
      }

      final nextType = currentPunchStatus.value == "in" ? "Out" : "In";

      // =========================================
      // GET PREMISES
      // =========================================

      final premises = await _apiService.getPremises(
        username: username,
      );

      if (premises.isEmpty) {
        Get.snackbar(
          "Error",
          "No premises assigned",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        return;
      }

      // =========================================
      // LOCATION VALIDATION
      // =========================================

      final insidePremise = await LocationService.validateUserInPremise(
        premises,
      );

      if (!insidePremise) {
        Get.defaultDialog(
          title: "📍 Outside Premise",
          middleText: "You are outside allowed location",
          radius: 18,
          confirm: ElevatedButton(
            onPressed: () {
              Get.back();
            },
            child: const Text("OK"),
          ),
        );

        return;
      }

      // =========================================
      // SUBMIT PUNCH
      // =========================================

      final success = await _apiService.submitPunch(
        username: username,
        type: nextType,
      );

      if (success) {
        currentPunchStatus.value = nextType.toLowerCase();

        Get.snackbar(
          "Success",
          nextType == "In"
              ? "Punched In Successfully"
              : "Punched Out Successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 14,
        );
      }
    } catch (e) {
      print("PUNCH ERROR => $e");

      Get.snackbar(
        "Error",
        "Attendance failed",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
      // already completed
      if (task.isCompleted) {
        return;
      }

      // =========================================
      // CHECK PUNCH
      // =========================================

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

      if (username == null || username.isEmpty) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        return;
      }

      // =========================================
      // VALIDATE LOCATION
      // =========================================

      final premises = await _apiService.getPremises(
        username: username,
      );

      final insidePremise = await LocationService.validateUserInPremise(
        premises,
      );

      if (!insidePremise) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        Get.defaultDialog(
          title: "📍 Location Error",
          middleText: "Task can only be completed inside premise",
        );

        return;
      }

      // =========================================
      // IMAGE TASK
      // =========================================

      File? imageFile;

      if (task.howrMethod.toLowerCase().contains("upload") ||
          task.howrMethod.toLowerCase().contains("image")) {
        imageFile = await pickImage();

        if (imageFile == null) {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }

          Get.snackbar(
            "Image Required",
            "Please upload proof image",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );

          return;
        }
      }

      // =========================================
      // FORM TASK
      // =========================================

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

      // =========================================
      // COMPLETE TASK API
      // =========================================

      final response = await _apiService.completeTask(
        username: username,
        madbId: task.id.toString(),
        imageFile: imageFile,
      );

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (response != null &&
          (response['status'] == true || response['success'] == true)) {
        task.isCompleted = true;

        tasks.refresh();

        // sort again
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
          margin: const EdgeInsets.all(12),
          borderRadius: 14,
        );
      } else {
        Get.snackbar(
          "Error",
          "Task completion failed",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
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
      print("IMAGE PICK ERROR => $e");

      return null;
    }
  }

  // =====================================================
  // HIGHLIGHT ANIMATION
  // =====================================================

  void startHighlightAnimation() {
    highlightTimer?.cancel();

    highlightTimer = Timer.periodic(
      const Duration(seconds: 4),
      (timer) {
        if (tasks.isEmpty) {
          return;
        }

        highlightedIndex.value++;

        if (highlightedIndex.value >= tasks.length) {
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
