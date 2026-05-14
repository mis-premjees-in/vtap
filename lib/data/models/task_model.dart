class TaskModel {
  final String id;

  // TASK
  final String taskEnglish;
  final String taskHindi;

  // TIME
  final String taskTime;

  // STATUS
  bool isCompleted;

  TaskModel({
    required this.id,
    required this.taskEnglish,
    required this.taskHindi,
    required this.taskTime,
    this.isCompleted = false,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['madb_id']?.toString() ?? "",

      // TASK TEXT
      taskEnglish: json['whats_what1']?.toString() ?? "",

      taskHindi: json['whats_what2']?.toString() ?? "",

      // TIME
      taskTime: json['whens_when3']?.toString() ?? "",

      isCompleted: false,
    );
  }
}
