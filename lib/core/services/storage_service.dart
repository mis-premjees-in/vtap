// core/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String tokenKey = "token";

  static const String usernameKey = "username";

  static const String userIdKey = "user_id";

  static const String whosIdKey = "whos_id";

  static const String attendanceKey = "attendance_status";

  static const String premiseNameKey = "premise_name";

  static const String googleEmailKey = "google_email";
  static const String googleUidKey = "google_uid";
  static const String googleTokenKey = "google_token";

  // =====================================================
  // SAVE LOGIN DATA
  // =====================================================

  static Future<void> saveLoginData({
    required String token,
    required String username,
    required String userId,
    required String whosId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(tokenKey, token);

    await prefs.setString(usernameKey, username);

    await prefs.setString(userIdKey, userId);

    await prefs.setString(whosIdKey, whosId);
  }

  static Future<void> saveGoogleData({
    required String email,
    required String uid,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      googleEmailKey,
      email,
    );

    await prefs.setString(
      googleUidKey,
      uid,
    );

    await prefs.setString(
      googleTokenKey,
      token,
    );
  }

  // =====================================================
  // SAVE ATTENDANCE
  // =====================================================

  static Future<void> saveAttendance({
    required String status,
    required String premiseName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(attendanceKey, status);

    await prefs.setString(premiseNameKey, premiseName);
  }

  // =====================================================
  // GET TOKEN
  // =====================================================

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(tokenKey) ?? '';
  }

  // =====================================================
  // GET USERNAME
  // =====================================================

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(usernameKey) ?? '';
  }

  // =====================================================
  // GET USER ID
  // =====================================================

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(userIdKey) ?? '';
  }

  // =====================================================
  // GET WHOS ID
  // =====================================================

  static Future<String> getWhosId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(whosIdKey) ?? '';
  }

  static Future<String> getGoogleEmail() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
          googleEmailKey,
        ) ??
        '';
  }

  static Future<String> getGoogleToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
          googleTokenKey,
        ) ??
        '';
  }

  static Future<String> getGoogleUid() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
          googleUidKey,
        ) ??
        '';
  }

  // =====================================================
  // GET ATTENDANCE
  // =====================================================

  static Future<String> getAttendanceStatus() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(attendanceKey) ?? "out";
  }

  // =====================================================
  // GET PREMISE NAME
  // =====================================================

  static Future<String> getPremiseName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(premiseNameKey) ?? "";
  }

  // =====================================================
  // CHECK LOGIN
  // =====================================================

  static Future<bool> isLoggedIn() async {
    final token = await getToken();

    return token.isNotEmpty;
  }

  // =====================================================
  // LOGOUT
  // =====================================================

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
  }
}
