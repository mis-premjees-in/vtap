import 'package:dio/dio.dart';

import '../../core/services/api_service.dart';

class AuthRepository {
  final ApiService apiService = ApiService();

  // ================= LOGIN =================

  Future<Response> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await apiService.dio.post(
        "/auth.php",
        data: {
          "username": username,
          "password": password,

          // Device id later dynamic hoga
          "md5": "00:C7:A8:B8:4D:DD:92",
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
