import 'package:dio/dio.dart';

import 'storage_service.dart';

class ApiService {
  late Dio dio;

  // =====================================================
  // BASE URL
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
        "/auth.php",
        data: {
          "username": username,
          "password": password,
          "md5": md5,
        },
      );

      return Map<String, dynamic>.from(
        response.data,
      );
    } catch (e) {
      throw Exception(
        "Login API Error: $e",
      );
    }
  }

  // =====================================================
  // GET TASKS
  // =====================================================

  Future<Map<String, dynamic>> getTasks({
    required String username,
  }) async {
    try {
      // =====================================================
      // GET TOKEN
      // =====================================================

      final token = await StorageService.getToken();

      print("TOKEN FROM STORAGE => $token");

      if (token.isEmpty) {
        throw Exception("Token not found");
      }

      List<dynamic> allRecords = [];

      int currentPage = 1;
      int totalPages = 1;

      // =====================================================
      // FETCH ALL PAGES
      // =====================================================

      do {
        final response = await dio.post(
          "/get_table_data.php",
          data: {
            "table_name": "madb",
            "username": username,
            "custom_where": "whos_who2='$username'",
            "access_token": token,
            "page": currentPage,
          },
          options: Options(
            headers: {
              "Authorization": "Bearer $token",
            },
          ),
        );

        print("TASK PAGE $currentPage => ${response.data}");

        final data = Map<String, dynamic>.from(response.data);

        if (data['status'] == true && data['response']['Error'] == "0") {
          final responseData = data['response'];

          final List records = responseData['Records'] ?? [];

          allRecords.addAll(records);

          totalPages = int.tryParse(
                responseData['Total_Pages'].toString(),
              ) ??
              1;

          currentPage++;
        } else {
          break;
        }
      } while (currentPage <= totalPages);

      print("TOTAL TASKS FETCHED => ${allRecords.length}");

      return {
        "status": true,
        "response": {
          "Error": "0",
          "Records": allRecords,
        }
      };
    } on DioException catch (e) {
      print("DIO ERROR => ${e.response?.data}");

      throw Exception(
        e.response?.data.toString() ?? "Failed to fetch tasks",
      );
    } catch (e) {
      print("GENERAL ERROR => $e");

      throw Exception(
        "Task API Error: $e",
      );
    }
  }

  // =====================================================
  // GET COMPLETED TASKS FROM UTEDB
  // =====================================================

  // =====================================================
// GET TODAY COMPLETED TASKS FROM UTEDB
// =====================================================

  Future<List<dynamic>> getCompletedTasks({
    required String username,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token.isEmpty) {
        return [];
      }

      // =====================================================
      // FETCH UTEDB
      // =====================================================

      final response = await dio.post(
        "/get_table_data.php",
        data: {
          "table_name": "utedb",
          "username": username,
          "access_token": token,
        },
      );

      print(
        "UTEDB RESPONSE => ${response.data}",
      );

      final data = Map<String, dynamic>.from(
        response.data,
      );

      // =====================================================
      // VALIDATION
      // =====================================================

      if (data['status'] == true && data['response']['Error'] == "0") {
        final List records = data['response']['Records'] ?? [];

        // =====================================================
        // TODAY DATE
        // =====================================================

        final now = DateTime.now();

        // =====================================================
        // FILTER ONLY TODAY TASKS
        // =====================================================

        final todayCompletedTasks = records.where((task) {
          try {
            final createdAt = task['utedb_created']?.toString() ?? "";

            if (createdAt.isEmpty) {
              return false;
            }

            final date = DateTime.parse(createdAt);

            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          } catch (e) {
            return false;
          }
        }).toList();

        print(
          "TODAY COMPLETED TASKS => $todayCompletedTasks",
        );

        return todayCompletedTasks;
      }

      return [];
    } catch (e) {
      print(
        "GET COMPLETED TASKS ERROR => $e",
      );

      return [];
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
            // =====================================================
            // IMPORTANT
            // =====================================================

            "utedb_madb": madbId,
          },
        },
      );

      print(
        "COMPLETE TASK RESPONSE => ${response.data}",
      );

      return response.data;
    } catch (e) {
      print(
        "COMPLETE TASK ERROR => $e",
      );

      rethrow;
    }
  }
}
