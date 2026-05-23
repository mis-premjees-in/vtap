import 'dart:convert';

class TaskModel {
  final String id;
  final String taskEnglish;
  final String taskHindi;
  final String whenSession;
  final String whenTime;
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

  // Dynamic Score Calculation Method
  double get score {
    if (stepCheckstates.isEmpty) return 0.0;
    int tickedCount = stepCheckstates.where((e) => e == true).length;
    return (tickedCount / stepCheckstates.length) * 100;
  }

  // API Submission ke liye JSON string read karne ka helper
  String get getHowsJsonString {
    Map<String, bool> tempMap = {};
    List<String> steps = stepList;
    for (int i = 0; i < steps.length; i++) {
      if (i < stepCheckstates.length) {
        tempMap["step ${i + 1}"] = stepCheckstates[i];
      }
    }
    return jsonEncode(tempMap);
  }

  TaskModel({
    required this.id,
    required this.taskEnglish,
    required this.taskHindi,
    required this.whenSession,
    required this.whenTime,
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

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final task = TaskModel(
      id: json['madb_id'].toString(),
      taskEnglish: json['whats_what1'] ?? "",
      taskHindi: json['whats_what2'] ?? "",
      whenSession: json['whens_when2'] ?? "",
      whenTime: json['whens_when3'] ?? "",
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

    // Agar server back-end se completed checkpoint updates ka JSON load hota hai
    if (json['utedb_hows1'] != null &&
        json['utedb_hows1'].toString().isNotEmpty) {
      try {
        Map<String, dynamic> parsedMap =
            jsonDecode(json['utedb_hows1'].toString());
        List<String> steps = task.stepList;
        for (int i = 0; i < steps.length; i++) {
          if (parsedMap.containsKey("step ${i + 1}")) {
            task.stepCheckstates[i] = parsedMap["step ${i + 1}"] == true;
          }
        }
      } catch (e) {
        print("JSON STATE PARSING ERROR => $e");
      }
    }
    return task;
  }
}
