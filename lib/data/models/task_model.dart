class TaskModel {
  final String id;

  final String taskEnglish;
  final String taskHindi;

  final String taskTime;
  final String taskTimeType;

  final String location;
  final String locationType;

  final String assignedTo;

  final String howrMethod;
  final String howrType;
  final String howrUrl;

  bool isCompleted;

  final DateTime? createdAt;

  TaskModel({
    required this.id,
    required this.taskEnglish,
    required this.taskHindi,
    required this.taskTime,
    required this.taskTimeType,
    required this.location,
    required this.locationType,
    required this.assignedTo,
    required this.howrMethod,
    required this.howrType,
    required this.howrUrl,
    required this.isCompleted,
    required this.createdAt,
  });

  factory TaskModel.fromJson(
    Map<String, dynamic> json, {
    bool isCompleted = false,
  }) {
    return TaskModel(
      id: json['madb_id']?.toString() ?? '',
      taskEnglish: json['whats_what1']?.toString() ?? '',
      taskHindi: json['whats_what2']?.toString() ?? '',
      taskTime: json['whens_when2']?.toString() ?? '',
      taskTimeType: json['whens_when3']?.toString() ?? '',
      location: json['wheres_where1']?.toString() ?? '',
      locationType: json['whichs_which1']?.toString() ?? '',
      assignedTo: json['whos_who2']?.toString() ?? '',
      howrMethod: json['howrs_howr1']?.toString() ?? '',
      howrType: json['howrs_howr2']?.toString() ?? '',
      howrUrl: json['howrs_howr3']?.toString() ?? '',
      isCompleted: isCompleted,
      createdAt: json['madb_created'] != null
          ? DateTime.tryParse(json['madb_created'].toString())
          : null,
    );
  }
}
