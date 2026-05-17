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
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['madb_id'].toString(),
      taskEnglish: json['whats_what1'] ?? "",
      taskHindi: json['whats_what2'] ?? "",
      whenSession: json['whens_when2'] ?? "",
      whenTime: json['whens_when3'] ?? "",
      where: "${json['wheres_where1'] ?? ""} ${json['wheres_where2'] ?? ""}"
          .trim(),
      which: json['whichs_which1'] ?? "",
      who: json['whos_who2'] ?? "",
      hows: json['howss_hows1']?.toString() ?? "",
      howrMethod: json['howrs_howr1'] ?? "",
      howrType: json['howrs_howr2'] ?? "",
      howrUrl: json['howrs_howr3'] ?? "",
      premiseId: json['madb_premises_id']?.toString() ?? "",
    );
  }
}
