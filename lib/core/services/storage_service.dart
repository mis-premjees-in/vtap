// core/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String tokenKey = "token";
  static const String usernameKey = "username";
  static const String userIdKey = "user_id";
  static const String whosIdKey = "whos_id";

  static const String googleEmailKey = "google_email";
  static const String googleUidKey = "google_uid";
  static const String googleTokenKey = "google_token";

  static const String premiseNameKey = "premise_name";
  static const String attendanceKey = "attendance_status";

  // =====================================================
  // SAVE LOGIN DATA
  // =====================================================
  static Future<void> saveLoginData({
    required String token,
    required String username,
    required String userId,
    required String whosId,
    String? firstUser,
    String? firstToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(usernameKey, username);
    await prefs.setString(userIdKey, userId);
    await prefs.setString(whosIdKey, whosId);

    if (firstUser != null) {
      await prefs.setString('firstUser', firstUser.toString());
    }
    if (firstToken != null) {
      await prefs.setString('firstToken', firstToken.toString());
    }
  }

  static Future<void> saveGoogleData({
    required String email,
    required String uid,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(googleEmailKey, email);
    await prefs.setString(googleUidKey, uid);
    await prefs.setString(googleTokenKey, token);
  }

  // =====================================================
  // LOCAL ATTENDANCE WRITES CAUSING DRIFT BUGS ARE REMOVED
  // =====================================================
  // All operations are redirected to live server lookups.
  // Method structures are deleted or commented out to prevent background service drift.

  static Future<String> getToken() async =>
      (await SharedPreferences.getInstance()).getString(tokenKey) ?? '';
  static Future<String> getUsername() async =>
      (await SharedPreferences.getInstance()).getString(usernameKey) ?? '';
  static Future<String> getUserId() async =>
      (await SharedPreferences.getInstance()).getString(userIdKey) ?? '';
  static Future<String> getWhosId() async =>
      (await SharedPreferences.getInstance()).getString(whosIdKey) ?? '';

  static Future<String> getFirstUser() async =>
      (await SharedPreferences.getInstance()).getString('firstUser') ?? '';
  static Future<String> getFirstToken() async =>
      (await SharedPreferences.getInstance()).getString('firstToken') ?? '';

  static Future<String> getGoogleEmail() async =>
      (await SharedPreferences.getInstance()).getString(googleEmailKey) ?? '';
  static Future<String> getGoogleToken() async =>
      (await SharedPreferences.getInstance()).getString(googleTokenKey) ?? '';
  static Future<String> getGoogleUid() async =>
      (await SharedPreferences.getInstance()).getString(googleUidKey) ?? '';

  static Future<bool> isLoggedIn() async => (await getToken()).isNotEmpty;

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
