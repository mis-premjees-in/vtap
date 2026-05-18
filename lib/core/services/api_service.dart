import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

class ApiService {
  late Dio dio;

  static const String baseUrl = "https://tm.premjees.in/api/";

  static const String authUrl = "auth.php";
  static const String getTableDataUrl = "get_table_data.php";
  static const String createRecordUrl = "create_record.php";

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
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
        onError: (error, handler) {
          print("API ERROR => ${error.message}");
          print("API RESPONSE => ${error.response?.data}");

          handler.next(error);
        },
      ),
    );

    // =====================================================
    // LOGGING
    // =====================================================

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
      ),
    );
  }

  // =====================================================
  // COMMON ERROR HANDLER
  // =====================================================

  Exception handleError(dynamic e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return Exception("Connection timeout");

        case DioExceptionType.receiveTimeout:
          return Exception("Server taking too long to respond");

        case DioExceptionType.connectionError:
          return Exception("No internet connection");

        case DioExceptionType.badResponse:
          return Exception(
            e.response?.data.toString() ?? "Server error",
          );

        default:
          return Exception("Something went wrong");
      }
    }

    return Exception(e.toString());
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
        authUrl,
        data: {
          "username": username,
          "password": password,
          "md5": md5,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw handleError(e);
    }
  }

  // =====================================================
  // COMMON TABLE FETCH
  // =====================================================

  Future<Map<String, dynamic>> getTableData({
    required String tableName,
    required String username,
    String? access_token,
    String? customWhere,
    int pageNumber = 1,
  }) async {
    try {
      final token = access_token ?? await StorageService.getToken();

      final response = await dio.post(
        getTableDataUrl,
        data: {
          "username": username,
          "table_name": tableName,
          "access_token": token,
          "page_number": pageNumber,
          if (customWhere != null && customWhere.trim().isNotEmpty)
            "custom_where": customWhere,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw handleError(e);
    }
  }

  // =====================================================
  // GET PREMISES
  // =====================================================

  Future<List<dynamic>> getPremises({
    required String username,
  }) async {
    try {
      final response = await getTableData(
        tableName: "premises",
        username: username,
      );

      if (response['status'] == true && response['response']?['Error'] == "0") {
        return response['response']['Records'] ?? [];
      }

      return [];
    } catch (e) {
      print("GET PREMISES ERROR => $e");

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
      List<dynamic> allTasks = [];

      int page = 1;
      int totalPages = 1;

      do {
        final response = await getTableData(
          tableName: "madb",
          username: username,
          pageNumber: page,
          customWhere:
              username != "tm_premjees" ? "whos_who2='$username'" : null,
        );

        if (response['status'] == true &&
            response['response']?['Error'] == "0") {
          final records = response['response']['Records'] ?? [];

          allTasks.addAll(records);

          totalPages = int.tryParse(
                response['response']['Total_Pages'].toString(),
              ) ??
              1;

          page++;
        } else {
          break;
        }
      } while (page <= totalPages);

      return allTasks;
    } catch (e) {
      print("GET TASKS ERROR => $e");

      throw Exception("Failed to load tasks");
    }
  }

  // =====================================================
  // GET TODAY COMPLETED TASKS
  // =====================================================

  Future<List<dynamic>> getTodayCompletedTasks({
    required String username,
  }) async {
    try {
      final now = DateTime.now();

      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final response = await getTableData(
        tableName: "utedb",
        username: username,
        customWhere: "whos_who2='$username' AND DATE(utedb_created)='$today'",
      );

      if (response['status'] == true && response['response']?['Error'] == "0") {
        return response['response']['Records'] ?? [];
      }

      return [];
    } catch (e) {
      print("COMPLETED TASK ERROR => $e");

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
      final response = await getTableData(
        tableName: "pnb",
        username: username,
        customWhere: "whos_who2='$username'",
      );

      if (response['status'] == true && response['response']?['Error'] == "0") {
        final records = response['response']['Records'] ?? [];

        if (records.isNotEmpty) {
          return records.first['pnb_type']?.toString().toLowerCase() ?? "out";
        }
      }

      return "out";
    } catch (e) {
      print("PUNCH STATUS ERROR => $e");

      return "out";
    }
  }

  // =====================================================
  // SUBMIT PUNCH
  // =====================================================

  Future<bool> submitPunch({
    required String username,
    required String type,
    required String premiseId,
    required String whosId,
  }) async {
    try {
      final token = await StorageService.getToken();

      final response = await dio.post(
        createRecordUrl,
        data: {
          "table_name": "pnb",
          "username": username,
          "access_token": token,
          "data": {
            "pnb_type": type,
            "pnb_premises_id": premiseId,
            "pnb_whos_id": whosId,
          },
        },
      );

      print("PUNCH RESPONSE => ${response.data}");

      return response.data['status'] == true;
    } catch (e) {
      print("PUNCH ERROR => $e");

      return false;
    }
  }

  // =====================================================
  // COMPLETE TASK
  // =====================================================

  Future<Map<String, dynamic>> completeTask({
    required String username,
    required String madbId,
    required String premiseId,
    // required String userId,
    File? imageFile,
  }) async {
    try {
      final token = await StorageService.getToken();

      // FormData formData = FormData.fromMap({
      //   "username": username,
      //   "table_name": "utedb",
      //   "access_token": token,
      //   "data": {"utedb_madb": madbId, "utedb_premises_id": premiseId}
      // });

      // print(jsonEncode(formData));

      // // =====================================================
      // // IMAGE
      // // =====================================================

      // if (imageFile != null) {
      //   final compressedImage = await compressImage(imageFile);

      //   formData.files.add(
      //     MapEntry(
      //       "proof_image",
      //       await MultipartFile.fromFile(
      //         compressedImage.path,
      //         filename: compressedImage.path.split('/').last,
      //       ),
      //     ),
      //   );
      // }

      // final response = await dio.post(
      //   createRecordUrl,
      //   data: jsonEncode(formData),
      //   options: Options(
      //     headers: {
      //       "Content-Type": "multipart/form-data",
      //     },
      //   ),
      // );

      // 1. Create your FormData with the nested map JSON-encoded (highly recommended for APIs)
      // 1. Convert ONLY the nested map to a JSON string
      // 1. Prepare your base payload variables
      String base64Image = "";

// =====================================================
// IMAGE TO BASE64 CONVERSION
// =====================================================
      if (imageFile != null) {
        final compressedImage = await compressImage(imageFile);

        // Read the compressed image file bytes
        List<int> imageBytes = await compressedImage.readAsBytes();

        // Convert bytes to a Base64 string
        // base64Image = base64Encode(imageBytes);
        base64Image = "data:image/jpg;base64${base64Encode(imageBytes)}";
      }

// 2. Build a normal Map (NOT FormData)
      Map<String, dynamic> requestPayload = {
        "username": username,
        "table_name": "utedb",
        "access_token": token,
        "data": {
          "utedb_madb": madbId,
          "utedb_premises_id": premiseId,
          "utedb_proof_image": base64Image,
          // "latitute": lat,
          // "longitude":,
        },
        // This is now a long text string
      };

// Debug print your payload as a clean JSON string
      print("Sending JSON -> ${jsonEncode(requestPayload)}");

// 3. Send it as raw JSON via Dio
      final response = await dio.post(
        createRecordUrl,
        data:
            jsonEncode(requestPayload), // Yes! Now you CAN use jsonEncode here
        options: Options(
          headers: {
            "Content-Type": "application/json", // Explicitly JSON now
          },
        ),
      );
      return Map<String, dynamic>.from(
        response.data,
      );
    } catch (e) {
      print("COMPLETE TASK ERROR => $e");

      throw Exception("Task completion failed");
    }
  }

  // =====================================================
  // COMPRESS IMAGE
  // =====================================================

  Future<File> compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();

      final targetPath =
          "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 45,
      );

      if (compressed == null) {
        return file;
      }

      return File(compressed.path);
    } catch (e) {
      print("IMAGE COMPRESS ERROR => $e");

      return file;
    }
  }
}
