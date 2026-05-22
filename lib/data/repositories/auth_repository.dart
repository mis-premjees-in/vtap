import 'package:dio/dio.dart';

import '../../core/services/api_service.dart';

class AuthRepository {
  final ApiService apiService = ApiService();

  // ================= LOGIN =================

  Future<Response> login({
    required String username,
    String password = "",
    String md5 = "",
  }) async {
    return await apiService.dio.post(
      "auth.php",
      data: {
        "username": username,
        "password": password,
        "md5": md5,
      },
    );
  }
}
