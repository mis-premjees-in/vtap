// core/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String tokenKey = "token";
  static const String usernameKey = "username";
  static const String userIdKey = "user_id";

  // ================= SAVE LOGIN DATA =================

  static Future<void> saveLoginData({
    required String token,
    required String username,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(tokenKey, token);
    await prefs.setString(usernameKey, username);
    await prefs.setString(userIdKey, userId);
  }

  // ================= GET TOKEN =================

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(tokenKey) ?? '';
  }

  // ================= GET USERNAME =================

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(usernameKey) ?? '';
  }

  // ================= GET USER ID =================

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(userIdKey) ?? '';
  }

  // ================= CHECK LOGIN =================

  static Future<bool> isLoggedIn() async {
    final token = await getToken();

    return token.isNotEmpty;
  }

  // ================= LOGOUT =================

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
