import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/models/task_model.dart';
import '../../../core/services/location_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class DashboardController extends GetxController {
  final ApiService _apiService = ApiService();
  // LOADING
  RxBool isLoading = false.obs;

  // LANGUAGE
  RxBool isHindi = false.obs;

  // VIEW
  RxBool isCarousel = false.obs;

  // TASKS
  RxList<TaskModel> tasks = <TaskModel>[].obs;

  // HIGHLIGHTED TASK
  RxInt highlightedIndex = (-1).obs;
  Timer? taskTimer;

  @override
  void onInit() {
    super.onInit();
    fetchTasks();
    startTaskHighlighter();
  }

  // =====================================================
  // FETCH TASKS
  // =====================================================

  Future<void> fetchTasks() async {
    try {
      isLoading.value = true;

      final username = await StorageService.getUsername();

      if (username.isEmpty) {
        Get.snackbar(
          "Error",
          "Username not found",
        );

        return;
      }

      // =====================================================
      // FETCH MADB TASKS
      // =====================================================

      final madbResponse = await _apiService.getTasks(
        username: username,
      );

      // =====================================================
      // FETCH UTEDB COMPLETED TASKS
      // =====================================================

      final completedTasks = await _apiService.getCompletedTasks(
        username: username,
      );

      print(
        "COMPLETED TASKS => $completedTasks",
      );

      // =====================================================
      // CREATE COMPLETED IDS LIST
      // =====================================================

      final completedMadbIds = completedTasks
          .map(
            (e) => e['utedb_madb'].toString(),
          )
          .toSet()
          .toList();

      print(
        "COMPLETED IDS => $completedMadbIds",
      );

      // =====================================================
      // VALIDATION
      // =====================================================

      if (madbResponse['status'] == true) {
        final responseData = madbResponse['response'];

        if (responseData != null && responseData['Error'] == "0") {
          final List records = responseData['Records'] ?? [];

          // =====================================================
          // STORE TASKS
          // =====================================================

          // =====================================================
// CONVERT TASKS
// =====================================================

          List<TaskModel> loadedTasks = records.map((e) {
            final task = TaskModel.fromJson(
              Map<String, dynamic>.from(e),
            );

            // =====================================================
            // CHECK COMPLETED TODAY
            // =====================================================

            if (completedMadbIds.contains(
              task.id.toString(),
            )) {
              task.isCompleted = true;
            }

            return task;
          }).toList();

// =====================================================
// SORT TASKS
// PENDING FIRST
// COMPLETED LAST
// =====================================================

          loadedTasks.sort((a, b) {
            if (a.isCompleted == b.isCompleted) {
              return 0;
            }

            return a.isCompleted ? 1 : -1;
          });

// =====================================================
// STORE TASKS
// =====================================================

          tasks.value = loadedTasks;

// =====================================================
// HIGHLIGHT FIRST PENDING TASK
// =====================================================

          highlightedIndex.value = tasks.indexWhere(
            (task) => !task.isCompleted,
          );

// IF ALL TASKS COMPLETED

          if (highlightedIndex.value == -1 && tasks.isNotEmpty) {
            highlightedIndex.value = 0;
          }

          print(
            "TASKS STORED => ${tasks.length}",
          );

          // if (tasks.isNotEmpty) {
          //   highlightedIndex.value = 0;
          // }

          print(
            "TASKS STORED => ${tasks.length}",
          );
        } else {
          tasks.clear();

          Get.snackbar(
            "Error",
            responseData?['Message'] ?? "No records found",
          );
        }
      } else {
        tasks.clear();

        Get.snackbar(
          "Error",
          "Failed to load tasks",
        );
      }
    } catch (e) {
      tasks.clear();

      print("FETCH TASK ERROR => $e");

      Get.snackbar(
        "Error",
        e.toString(),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =====================================================
  // LANGUAGE TOGGLE
  // =====================================================

  void toggleLanguage() {
    isHindi.value = !isHindi.value;
  }

  // =====================================================
  // VIEW TOGGLE
  // =====================================================

  void toggleView() {
    isCarousel.value = !isCarousel.value;
  }

  // =====================================================
  // AUTO TASK TIME HIGHLIGHTER
  // =====================================================

  void startTaskHighlighter() {
    // PREVENT MULTIPLE TIMERS

    taskTimer?.cancel();

    // CHECK EVERY 1 MINUTE

    taskTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) {
        checkTaskTime();
      },
    );

    // INITIAL CHECK

    checkTaskTime();
  }

  // =====================================================
  // CHECK CURRENT TASK TIME
  // =====================================================

  void checkTaskTime() {
    if (tasks.isEmpty) {
      return;
    }

    final now = TimeOfDay.now();

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];

      // SKIP COMPLETED TASKS

      if (task.isCompleted) {
        continue;
      }

      try {
        // EXPECTED FORMAT => 10:30

        final parts = task.taskTime.split(":");

        if (parts.length < 2) {
          continue;
        }

        final hour = int.parse(parts[0].trim());

        // final minute = int.parse(parts[1].trim());
        final minute = int.parse(
          parts[1].split(":")[0].trim(),
        );

        // =====================================================
        // MATCH CURRENT TIME
        // =====================================================

        if (hour == now.hour && minute == now.minute) {
          highlightedIndex.value = i;

          // =====================================================
          // SHOW POPUP
          // =====================================================

          Get.snackbar(
            "⏰ Task Reminder",
            task.taskEnglish,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 10),
          );

          break;
        }
      } catch (e) {
        print("TIME PARSE ERROR => $e");
      }
    }
  }

  // =====================================================
  // COMPLETE TASK AND SAVE INTO UTEDB
  // =====================================================

  Future<void> completeTask(int index) async {
    try {
      if (tasks[index].isCompleted) {
        return;
      }

      final isAllowed = await LocationService.canCompleteTask();

      if (!isAllowed) {
        Get.snackbar(
          "🌍 Arre, Babu Bhaiya!",
          "Lagta hai rasta bhatak gaye ho. 😄 Task poora karne ke liye wapis dukan pe aana padega!",
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 8),
        );

        return;
      }

      final username = await StorageService.getUsername();

      final response = await _apiService.completeTask(
        username: username,
        madbId: tasks[index].id,
      );

      print("COMPLETE RESPONSE => $response");

      if (response['status'] == true && response['response']['Error'] == "0") {
        tasks[index].isCompleted = true;
        // =====================================================
        // SORT AGAIN
        // =====================================================

        tasks.sort((a, b) {
          if (a.isCompleted == b.isCompleted) {
            return 0;
          }

          return a.isCompleted ? 1 : -1;
        });

        tasks.refresh();
        // =====================================================
        // UPDATE HIGHLIGHTED TASK
        // =====================================================

        highlightedIndex.value = tasks.indexWhere(
          (task) => !task.isCompleted,
        );

        if (highlightedIndex.value == -1 && tasks.isNotEmpty) {
          highlightedIndex.value = 0;
        }

        Get.snackbar(
          "Success",
          "Are waah tumne task complete krdiya! Shabash meri taraf se tumhe 7 crore free ✅",
        );
      } else {
        Get.snackbar(
          "Error",
          "Unable to complete task",
        );
      }
    } catch (e) {
      print("COMPLETE TASK ERROR => $e");

      Get.snackbar(
        "Error",
        e.toString(),
      );
    }
  }

  // =====================================================
  // DISPOSE TIMER
  // =====================================================

  @override
  void onClose() {
    taskTimer?.cancel();

    super.onClose();
  }
}
