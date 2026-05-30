import 'dart:convert';
import 'package:flutter/foundation.dart';

class TaskModel {
  final String id;
  final String taskEnglish;
  final String taskHindi;
  final String whenSession;
  final String whenTime;
  final String frequency;
  final String where;
  final String which;
  final String who;
  final String hows;
  final String howrMethod;
  final String howrType;
  final String howrUrl;
  final String premiseId;
  bool isCompleted;

  // New: Checkbox state management
  List<bool> stepCheckstates = [];
  Map<String, bool> howsJson = {};
  List<String> get stepList =>
      hows.split('\n').where((s) => s.trim().isNotEmpty).toList();

  bool get isUploadProofTask =>
      howrMethod.toLowerCase().contains("upload") ||
      howrMethod.toLowerCase().contains("image") ||
      howrMethod.toLowerCase().contains("proof");

  bool get isExternalFormTask => howrUrl.trim().isNotEmpty;

  bool get isSimpleTask => !isUploadProofTask && !isExternalFormTask;

  // Dynamic Score Calculation Method
  double get score {
    if (stepCheckstates.isEmpty) return 100.0;
    int tickedCount = stepCheckstates.where((e) => e == true).length;
    return (tickedCount / stepCheckstates.length) * 100;
  }

  // 2. Updated JSON String (Isme ab score bhi include hoga)
  String get getHowsJsonString {
    Map<String, dynamic> tempMap = {};
    List<String> steps = stepList;

    for (int i = 0; i < steps.length; i++) {
      String stepText = steps[i].trim();
      if (i < stepCheckstates.length) {
        tempMap[stepText] = stepCheckstates[i];
      }
    }

    // ADDED: Last me score bhi save karein JSON me
    tempMap["final_task_score"] = score.toStringAsFixed(0);

    return jsonEncode(tempMap);
  }

  TaskModel({
    required this.id,
    required this.taskEnglish,
    required this.taskHindi,
    required this.whenSession,
    required this.whenTime,
    required this.frequency,
    required this.where,
    required this.which,
    required this.who,
    required this.hows,
    required this.howrMethod,
    required this.howrType,
    required this.howrUrl,
    required this.premiseId,
    this.isCompleted = false,
  }) {
    // Initialize checkboxes as false
    stepCheckstates = List.filled(stepList.length, false);
  }

// 3. Factory constructor me parsing logic update karein
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final task = TaskModel(
      id: json['madb_id'].toString(),
      taskEnglish: json['whats_what1'] ?? "",
      taskHindi: json['whats_what2'] ?? "",
      whenSession: json['whens_when2'] ?? "",
      whenTime: json['whens_when3'] ?? "",
      frequency: json['whens_when1']?.toString() ?? "Daily",
      where: "${json['wheres_where1'] ?? ""} ${json['wheres_where2'] ?? ""}"
          .trim(),
      which: json['whichs_which1'] ?? "",
      who: "",
      hows: json['howss_hows1']?.toString() ?? "",
      howrMethod: json['howrs_howr1'] ?? "",
      howrType: json['howrs_howr2'] ?? "",
      howrUrl: json['howrs_howr3'] ?? "",
      premiseId: json['madb_premises_id']?.toString() ?? "",
    );

    if (json['utedb_hows1'] != null &&
        json['utedb_hows1'].toString().isNotEmpty) {
      try {
        Map<String, dynamic> parsedMap =
            jsonDecode(json['utedb_hows1'].toString());
        List<String> steps = task.stepList;

        for (int i = 0; i < steps.length; i++) {
          String stepText = steps[i].trim();
          if (parsedMap.containsKey(stepText)) {
            task.stepCheckstates[i] = parsedMap[stepText] == true;
          }
        }
        // Note: Score automatic calculate ho jayega stepCheckstates se
      } catch (e) {
        debugPrint("JSON SYNC ERROR => $e");
      }
    }
    return task;
  }
}
