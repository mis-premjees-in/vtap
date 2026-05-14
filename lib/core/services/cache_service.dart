import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String cachedTasksKey = "cached_tasks";

  /// SAVE TASKS JSON STRING
  static Future<void> saveTasks(String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(cachedTasksKey, data);
    } catch (e) {
      print("CACHE SAVE ERROR: $e");
    }
  }

  /// SAVE MAP/LIST DIRECTLY
  static Future<void> saveJson(dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final encoded = jsonEncode(data);

      await prefs.setString(cachedTasksKey, encoded);
    } catch (e) {
      print("CACHE JSON SAVE ERROR: $e");
    }
  }

  /// GET RAW STRING
  static Future<String> getTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getString(cachedTasksKey) ?? "";
    } catch (e) {
      print("CACHE FETCH ERROR: $e");

      return "";
    }
  }

  /// GET DECODED JSON
  static Future<dynamic> getJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = prefs.getString(cachedTasksKey);

      if (data == null || data.isEmpty) {
        return null;
      }

      return jsonDecode(data);
    } catch (e) {
      print("CACHE JSON ERROR: $e");

      return null;
    }
  }

  /// CLEAR CACHE
  static Future<void> clearTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(cachedTasksKey);
    } catch (e) {
      print("CACHE CLEAR ERROR: $e");
    }
  }
}
