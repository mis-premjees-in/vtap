import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

class ApiService {
  late Dio dio;

  static const String baseUrl = "https://tm.premjees.in/api/";

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          "Content-Type": "application/json",
        },
      ),
    );

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

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );
  }

  // =====================================================
  // LOGIN
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
    } on DioException catch (e) {
      throw Exception(
        e.response?.data.toString() ?? "Internet connection problem",
      );
    }
  }

  // =====================================================
  // GET PREMISES
  // =====================================================

  Future<List<dynamic>> getPremises({
    required String username,
  }) async {
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
      return [];
    }
  }

  // =====================================================
  // GET TASKS
  // =====================================================

  Future<List<dynamic>> getTasks({
    required String username,
  }) async {
    try {
      final token = await StorageService.getToken();

      List<dynamic> allTasks = [];

      int page = 1;
      int totalPages = 1;

      do {
        Map<String, dynamic> data = {
          "username": username,
          "table_name": "madb",
          "access_token": token,
          "page": page,
        };

        if (username != "tm_premjees") {
          data["custom_where"] = "whos_who2='$username'";
        }

        final response = await dio.post(
          "get_table_data.php",
          data: data,
        );

        if (response.data['status'] == true &&
            response.data['response']['Error'] == "0") {
          final records = response.data['response']['Records'] ?? [];

          allTasks.addAll(records);

          totalPages = int.tryParse(
                response.data['response']['Total_Pages'].toString(),
              ) ??
              1;

          page++;
        } else {
          break;
        }
      } while (page <= totalPages);

      return allTasks;
    } catch (e) {
      throw Exception("Failed to load tasks");
    }
  }

  // =====================================================
  // GET COMPLETED TASKS
  // =====================================================

  Future<List<dynamic>> getTodayCompletedTasks({
    required String username,
  }) async {
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
        return response.data['response']['Records'] ?? [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // =====================================================
  // GET LAST PUNCH STATUS
  // =====================================================

  Future<String> getLastPunchStatus({
    required String username,
  }) async {
    try {
      final token = await StorageService.getToken();

      final response = await dio.post(
        "get_table_data.php",
        data: {
          "username": username,
          "table_name": "pnb",
          "access_token": token,
        },
      );

      if (response.data['status'] == true) {
        final records = response.data['response']['Records'] ?? [];

        if (records.isNotEmpty) {
          return records.first['pnb_type']?.toString().toLowerCase() ?? "out";
        }
      }

      return "out";
    } catch (e) {
      return "out";
    }
  }

  // =====================================================
  // SUBMIT PUNCH
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
      return false;
    }
  }

  // =====================================================
  // COMPLETE TASK
  // =====================================================

  Future<Map<String, dynamic>> completeTask({
    required String username,
    required String madbId,
    File? imageFile,
  }) async {
    try {
      final token = await StorageService.getToken();

      FormData formData = FormData.fromMap({
        "username": username,
        "table_name": "utedb",
        "access_token": token,
        "data": {
          "utedb_madb": madbId,
        },
      });

      if (imageFile != null) {
        File compressed = await compressImage(imageFile);

        formData.files.add(
          MapEntry(
            "proof_image",
            await MultipartFile.fromFile(
              compressed.path,
              filename: compressed.path.split('/').last,
            ),
          ),
        );
      }

      final response = await dio.post(
        "create_record.php",
        data: formData,
        options: Options(
          headers: {
            "Content-Type": "multipart/form-data",
          },
        ),
      );

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception("Task complete failed");
    }
  }

  // =====================================================
  // COMPRESS IMAGE
  // =====================================================

  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();

    final targetPath =
        "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 45,
    );

    return File(compressed!.path);
  }
}
