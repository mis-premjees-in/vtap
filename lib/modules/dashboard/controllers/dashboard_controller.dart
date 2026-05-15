import 'package:get/get.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/models/task_model.dart';
import '../../../core/services/location_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class DashboardController extends GetxController {
  final ApiService _apiService = ApiService();

  RxBool isLoading = false.obs;
  RxBool isPunching = false.obs;
  RxBool isHindi = false.obs;
  RxBool isCarousel = false.obs;
  RxList<TaskModel> tasks = <TaskModel>[].obs;
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
        Get.snackbar("Error", "Username not found");
        return;
      }

      final response = await _apiService.getTasks(username: username);

      if (response['status'] == true) {
        final List<dynamic> records = response['response']?['Records'] ?? [];

        final completedToday =
            await _apiService.getTodayCompletedTasks(username: username);
        final completedIds =
            completedToday.map((e) => e['utedb_madb'].toString()).toSet();

        final List<TaskModel> fetchedTasks = records.map((json) {
          final task = TaskModel.fromJson(json);
          if (completedIds.contains(task.id.toString())) {
            task.isCompleted = true;
          }
          return task;
        }).toList();

        fetchedTasks.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return a.taskTime.compareTo(b.taskTime);
        });

        tasks.assignAll(fetchedTasks);
        highlightedIndex.value = tasks.indexWhere((task) => !task.isCompleted);
      }
    } catch (e) {
      print("FETCH TASKS ERROR => $e");
    } finally {
      isLoading.value = false;
    }
  }

  // =====================================================
  // PUNCH ACTION (In / Out)
  // =====================================================
  Future<void> handlePunchAction(String type) async {
    try {
      isPunching.value = true;
      final username = await StorageService.getUsername();

      // 1. Fetch premises list from API first
      List<dynamic> premises =
          await _apiService.getPremises(username: username);

      // 2. Pass the list to LocationService as it now expects an argument
      bool insideRadius = await LocationService.canCompleteTask(premises);

      if (!insideRadius) {
        Get.snackbar("Location Error",
            "You must be within a valid office radius to mark attendance.",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      // 3. Submit Punch
      bool success = await _apiService.submitPunch(
        username: username,
        type: type, // "In" or "Out"
      );

      if (success) {
        Get.snackbar("Attendance", "Punch $type recorded successfully!",
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar("Error", "Failed to record punch.");
      }
    } catch (e) {
      Get.snackbar("Error", "Something went wrong.");
    } finally {
      isPunching.value = false;
    }
  }

  // =====================================================
  // COMPLETE TASK
  // =====================================================
  Future<void> completeTask(int index) async {
    try {
      final username = await StorageService.getUsername();

      // 1. Fetch premises for location validation
      List<dynamic> premises =
          await _apiService.getPremises(username: username);

      // 2. Validate location with the premises list
      bool insideRadius = await LocationService.canCompleteTask(premises);

      if (!insideRadius) {
        Get.snackbar("Location Error", "You are not at the required location.");
        return;
      }

      final response = await _apiService.completeTask(
        username: username,
        madbId: tasks[index].id,
      );

      if (response != null &&
          response['status'] == true &&
          response['response']['Error'] == "0") {
        tasks[index].isCompleted = true;
        tasks.sort((a, b) => (a.isCompleted ? 1 : -1));
        tasks.refresh();
        highlightedIndex.value = tasks.indexWhere((t) => !t.isCompleted);
        Get.snackbar("Success", "Task completed!");
      }
    } catch (e) {
      Get.snackbar("Error", "Unable to complete task");
    }
  }

  void startTaskHighlighter() {
    taskTimer?.cancel();
    taskTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (tasks.isNotEmpty) {
        int current = highlightedIndex.value;
        highlightedIndex.value = (current + 1) % tasks.length;
      }
    });
  }

  @override
  void onClose() {
    taskTimer?.cancel();
    super.onClose();
  }
}
