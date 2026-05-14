import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiService1 {
  late Dio dio;

  // =====================================================
  // BASE URL
  // =====================================================
  static const String baseUrl = "https://tm.premjees.in/api/";

  ApiService1() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          "Content-Type": "application/json",
        },
      ),
    );

    // =====================================================
    // TOKEN INTERCEPTOR
    // =====================================================
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          handler.next(options);
        },
      ),
    );

    // =====================================================
    // LOGGER
    // =====================================================
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );
  }

  // =====================================================
  // GET PREMISES
  // =====================================================
  Future<List<dynamic>> getPremises({required String username}) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "/read_record.php",
        data: {
          "username": username,
          "table_name": "premises",
          "access_token": token,
        },
      );

      if (response.data['status'] == true) {
        return response.data['response']['Records'] ?? [];
      }
      return [];
    } catch (e) {
      print("GET PREMISES ERROR => $e");
      return [];
    }
  }

  // =====================================================
  // GET TASKS (Mantra DB)
  // =====================================================
  Future<dynamic> getTasks({required String username}) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "/read_record.php",
        data: {
          "username": username,
          "table_name": "madb",
          "access_token": token,
        },
      );
      return response.data;
    } catch (e) {
      print("GET TASKS ERROR => $e");
      return null;
    }
  }

  // =====================================================
  // GET TODAY'S COMPLETED TASKS
  // =====================================================
  Future<List<dynamic>> getTodayCompletedTasks(
      {required String username}) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "/read_record.php",
        data: {
          "username": username,
          "table_name": "utedb",
          "access_token": token,
        },
      );

      if (response.data['status'] == true) {
        List<dynamic> records = response.data['response']['Records'] ?? [];
        DateTime now = DateTime.now();

        // Filter records created today
        final todayCompletedTasks = records.where((record) {
          try {
            String createdAt = record['created_at'];
            DateTime date = DateTime.parse(createdAt);
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          } catch (e) {
            return false;
          }
        }).toList();

        return todayCompletedTasks;
      }
      return [];
    } catch (e) {
      print("GET COMPLETED TASKS ERROR => $e");
      return [];
    }
  }

  // =====================================================
  // SUBMIT PUNCH (Simplified Payload)
  // =====================================================
  Future<bool> submitPunch({
    required String username,
    required String type, // "In" or "Out"
  }) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "/create_record.php",
        data: {
          "username": username,
          "table_name": "pnb",
          "access_token": token,
          "data": {
            "pnb_type": type,
          },
        },
      );

      // Status true and Error code "0" indicates success
      return response.data['status'] == true &&
          response.data['response']['Error'] == "0";
    } catch (e) {
      print("SUBMIT PUNCH ERROR => $e");
      return false;
    }
  }

  // =====================================================
  // COMPLETE TASK
  // =====================================================
  Future<dynamic> completeTask({
    required String username,
    required String madbId,
  }) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "/create_record.php",
        data: {
          "username": username,
          "table_name": "utedb",
          "access_token": token,
          "data": {
            "utedb_madb": madbId,
          },
        },
      );
      return response.data;
    } catch (e) {
      print("COMPLETE TASK ERROR => $e");
      return null;
    }
  }
}
