import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../models/task_model.dart';

class TaskRepository {
  final ApiService apiService = ApiService();

  // =====================================================
  // FETCH & MERGE TODAY'S TASKS
  // =====================================================
  Future<List<TaskModel>> getTodayTasks(String username) async {
    final dynamic masterResponse = await apiService.getTasks(username: username);
    final dynamic completedResponse = await apiService.getTodayCompletedTasks(username: username);

    final Set<String> todayCompletedMadbIds = {};
    final Map<String, String> utedbHowsMap = {};
    final now = DateTime.now();
    final String todayDateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Safe evaluation array extraction for completed entries
    List<dynamic> completedRecords = [];
    if (completedResponse != null) {
      if (completedResponse is List) {
        completedRecords = completedResponse;
      } else if (completedResponse is Map &&
          completedResponse['response']?['Records'] is List) {
        completedRecords = completedResponse['response']['Records'];
      }
    }

    for (final item in completedRecords) {
      if (item is Map) {
        String createdDate = item['utedb_created']?.toString() ?? "";
        if (createdDate.startsWith(todayDateStr)) {
          String mid = item['utedb_madb']?.toString() ?? "";
          if (mid.isNotEmpty) {
            todayCompletedMadbIds.add(mid);
            if (item['utedb_hows1'] != null) {
              utedbHowsMap[mid] = item['utedb_hows1'].toString();
            }
          }
        }
      }
    }

    // Safe evaluation array extraction for master records
    List<dynamic> masterRecords = [];
    if (masterResponse != null) {
      if (masterResponse is List) {
        masterRecords = masterResponse;
      } else if (masterResponse is Map &&
          masterResponse['response']?['Records'] is List) {
        masterRecords = masterResponse['response']['Records'];
      }
    }

    List<TaskModel> mergedTasks = [];
    for (final item in masterRecords) {
      try {
        if (item is Map) {
          Map<String, dynamic> taskData =
              item.map((k, v) => MapEntry(k.toString(), v));
          String tid = taskData['madb_id']?.toString() ?? "";

          if (tid.isNotEmpty) {
            bool isDone = todayCompletedMadbIds.contains(tid);
            if (isDone && utedbHowsMap.containsKey(tid)) {
              taskData['utedb_hows1'] = utedbHowsMap[tid];
            }

            final task = TaskModel.fromJson(taskData);
            task.isCompleted = isDone;
            mergedTasks.add(task);
          }
        }
      } catch (innerMappingError) {
        debugPrint("CORRUPTED RECORD ROW SKIPPED CORRECTION => $innerMappingError");
      }
    }

    mergedTasks.sort((a, b) =>
        a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1));
    return mergedTasks;
  }

  // =====================================================
  // COMPLETE TASK
  // =====================================================
  Future<Map<String, dynamic>> completeTask({
    required String username,
    required String madbId,
    required String premiseId,
    required String howsJsonString,
    File? imageFile,
    String? precomputedBase64Image,
    double? precomputedLat,
    double? precomputedLng,
  }) async {
    return await apiService.completeTask(
      username: username,
      madbId: madbId,
      premiseId: premiseId,
      howsJsonString: howsJsonString,
      imageFile: imageFile,
      precomputedBase64Image: precomputedBase64Image,
      precomputedLat: precomputedLat,
      precomputedLng: precomputedLng,
    );
  }
}
