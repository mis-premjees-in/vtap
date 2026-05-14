import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiService {
  late Dio dio;

  // =====================================================
  // BASE URL (Simple /api/ path)
  // =====================================================
  static const String baseUrl = "https://tm.premjees.in/api/";

  ApiService() {
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
  // LOGIN API
  // =====================================================
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String md5,
  }) async {
    try {
      final response = await dio.post(
        "auth.php",
        data: {
          "username": username,
          "password": password,
          "md5": md5,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception("Login API Error: $e");
    }
  }

  // =====================================================
  // GET PREMISES
  // =====================================================
  Future<List<dynamic>> getPremises({required String username}) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "get_table_data.php",
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
  // GET TASKS (Priority Logic with Pagination)
  // =====================================================
  Future<Map<String, dynamic>> getTasks({required String username}) async {
    try {
      final token = await StorageService.getToken();
      if (token.isEmpty) throw Exception("Token not found");

      List<dynamic> allRecords = [];
      int currentPage = 1;
      int totalPages = 1;

      do {
        final response = await dio.post(
          "get_table_data.php",
          data: {
            "table_name": "madb",
            "username": username,
            "custom_where": "whos_who2='$username'",
            "access_token": token,
            "page": currentPage,
          },
        );

        final data = Map<String, dynamic>.from(response.data);
        if (data['status'] == true && data['response']['Error'] == "0") {
          final responseData = data['response'];
          final List records = responseData['Records'] ?? [];
          allRecords.addAll(records);
          totalPages =
              int.tryParse(responseData['Total_Pages'].toString()) ?? 1;
          currentPage++;
        } else {
          break;
        }
      } while (currentPage <= totalPages);

      return {
        "status": true,
        "response": {
          "Error": "0",
          "Records": allRecords,
        }
      };
    } on DioException catch (e) {
      throw Exception(e.response?.data.toString() ?? "Failed to fetch tasks");
    } catch (e) {
      throw Exception("Task API Error: $e");
    }
  }

  // =====================================================
  // GET TODAY COMPLETED TASKS
  // =====================================================
  Future<List<dynamic>> getTodayCompletedTasks(
      {required String username}) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "get_table_data.php",
        data: {
          "username": username,
          "table_name": "utedb",
          "access_token": token,
        },
      );

      if (response.data['status'] == true &&
          response.data['response']['Error'] == "0") {
        final List<dynamic> records =
            response.data['response']['Records'] ?? [];
        final now = DateTime.now();
        return records.where((task) {
          try {
            final createdAt = task['utedb_created']?.toString() ?? "";
            if (createdAt.isEmpty) return false;
            final date = DateTime.parse(createdAt);
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          } catch (e) {
            return false;
          }
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // =====================================================
  // GET LAST PUNCH STATUS
  // =====================================================
  Future<String> getLastPunchStatus({required String username}) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "get_table_data.php",
        data: {
          "username": username,
          "table_name": "pnb",
          "access_token": token,
          "page": 1,
        },
      );

      if (response.data['status'] == true) {
        final List records = response.data['response']['Records'] ?? [];
        if (records.isNotEmpty) {
          // Check the newest record
          return records.first['pnb_type']?.toString().toLowerCase() ?? "out";
        }
      }
      return "out";
    } catch (e) {
      return "out";
    }
  }

  // =====================================================
  // COMPLETE TASK
  // =====================================================
  Future<dynamic> completeTask(
      {required String username, required String madbId}) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "create_record.php",
        data: {
          "username": username,
          "table_name": "utedb",
          "access_token": token,
          "data": {"utedb_madb": madbId},
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // =====================================================
  // SUBMIT PUNCH (Latitude/Longitude Removed as requested)
  // =====================================================
  Future<bool> submitPunch({
    required String username,
    required String type,
  }) async {
    try {
      final token = await StorageService.getToken();
      final response = await dio.post(
        "create_record.php",
        data: {
          "username": username,
          "table_name": "pnb",
          "access_token": token,
          "data": {
            "pnb_type": type,
          },
        },
      );
      return response.data['status'] == true &&
          response.data['response']['Error'] == "0";
    } catch (e) {
      print("SUBMIT PUNCH ERROR => $e");
      return false;
    }
  }
}
