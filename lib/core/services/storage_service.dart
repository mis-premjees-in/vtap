// core/services/storage_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String tokenKey = "token";
  static const String usernameKey = "username";
  static const String userIdKey = "user_id";
  static const String whosIdKey = "whos_id";

  static const String googleEmailKey = "google_email";
  static const String googleUidKey = "google_uid";
  static const String googleTokenKey = "google_token";
  static const String googleAccessTokenKey = "google_access_token";

  static const String premiseNameKey = "premise_name";
  static const String attendanceKey = "attendance_status";
  static const String groupIdKey = "group_id";
  static const String whosPremiseKey = "whos_premise";
  static const String premiseLatKey = "premise_lat";
  static const String premiseLngKey = "premise_lng";
  static const String premiseRadiusKey = "premise_radius";

  // =====================================================
  // SAVE LOGIN DATA
  // =====================================================
  static Future<void> saveLoginData({
    required String token,
    required String username,
    required String userId,
    required String whosId,
    String? groupId,
    String? firstUser,
    String? firstToken,
    String? whosPremise,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(usernameKey, username);
    await prefs.setString(userIdKey, userId);
    await prefs.setString(whosIdKey, whosId);
    if (groupId != null) {
      await prefs.setString(groupIdKey, groupId);
    }
    if (whosPremise != null) {
      await prefs.setString(whosPremiseKey, whosPremise);
    }

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
  static Future<String> getGoogleAccessToken() async =>
      (await SharedPreferences.getInstance()).getString(googleAccessTokenKey) ?? '';
  static Future<void> saveGoogleAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(googleAccessTokenKey, token);
  }
  static Future<String> getGoogleUid() async =>
      (await SharedPreferences.getInstance()).getString(googleUidKey) ?? '';

  static Future<bool> isLoggedIn() async => (await getToken()).isNotEmpty;

  static Future<String> getGroupId() async =>
      (await SharedPreferences.getInstance()).getString(groupIdKey) ?? '';

  static Future<bool> isAdmin() async => (await getGroupId()) == "2";

  static Future<String> getWhosPremise() async =>
      (await SharedPreferences.getInstance()).getString(whosPremiseKey) ?? '';

  static Future<void> saveWhosPremise(String premiseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(whosPremiseKey, premiseId);
  }

  static Future<void> savePremiseDetails({
    required double lat,
    required double lng,
    required double radius,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(premiseLatKey, lat);
    await prefs.setDouble(premiseLngKey, lng);
    await prefs.setDouble(premiseRadiusKey, radius);
    await prefs.setString(premiseNameKey, name);

    // Save as strings for native Android service to parse without type/bit representation issues
    await prefs.setString("${premiseLatKey}_str", lat.toString());
    await prefs.setString("${premiseLngKey}_str", lng.toString());
    await prefs.setString("${premiseRadiusKey}_str", radius.toString());
  }

  static Future<double?> getPremiseLat() async =>
      (await SharedPreferences.getInstance()).getDouble(premiseLatKey);

  static Future<double?> getPremiseLng() async =>
      (await SharedPreferences.getInstance()).getDouble(premiseLngKey);

  static Future<double?> getPremiseRadius() async =>
      (await SharedPreferences.getInstance()).getDouble(premiseRadiusKey);

  static Future<String> getPremiseName() async =>
      (await SharedPreferences.getInstance()).getString(premiseNameKey) ?? '';

  static Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  static Future<void> saveAttendanceStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(attendanceKey, status.toLowerCase().trim());
  }

  static Future<String> getAttendanceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(attendanceKey) ?? 'out';
  }

  static Future<File> get _logFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/background_logs.txt');
  }

  static Future<void> addLog(String log) async {
    try {
      final file = await _logFile;
      final timestamp = DateTime.now().toLocal().toString().substring(0, 19);
      final logLine = "[$timestamp] $log\n";
      
      debugPrint("BG_LOG: $logLine"); // Also print to debugger console
      
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
      
      // Limit file size to last 300 logs
      if (await file.exists()) {
        final length = await file.length();
        if (length > 100 * 1024) { // > 100 KB
          final lines = await file.readAsLines();
          if (lines.length > 300) {
            final trimmedLines = lines.sublist(lines.length - 300);
            await file.writeAsString("${trimmedLines.join('\n')}\n", flush: true);
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to save log to file: $e");
    }
  }

  static Future<List<String>> getLogs() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        return await file.readAsLines();
      }
      return [];
    } catch (e) {
      return ["Error loading logs: $e"];
    }
  }

  static Future<void> clearLogs() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Failed to clear logs file: $e");
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
