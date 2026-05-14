import 'package:dio/dio.dart';

import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class TaskRepository {
  final ApiService apiService = ApiService();

  // =====================================================
  // FETCH TASKS
  // =====================================================

  Future<Response> fetchTasks() async {
    try {
      final token = await StorageService.getToken();

      final response = await apiService.dio.post(
        "get_table_data.php",
        data: {
          "table_name": "madb",
          "username": "tm_premjees",
          "access_token": token,
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // =====================================================
  // COMPLETE TASK
  // =====================================================

  Future<Response> completeTask({
    required String taskId,
    required String remarks,
  }) async {
    try {
      final token = await StorageService.getToken();

      final response = await apiService.dio.post(
        "create_record",
        data: {
          "username": "tm_premjees",
          "table_name": "utedb",
          "data": {
            "task_id": taskId,
            "remarks": remarks,
            "status": "completed",
          },
          "access_token": token,
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
