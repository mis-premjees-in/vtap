import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../data/repositories/task_repository.dart';

class OfflineTaskSubmission {
  final String username;
  final String madbId;
  final String premiseId;
  final String howsJsonString;
  final String base64Image;
  final double latitude;
  final double longitude;
  final String timestamp;

  OfflineTaskSubmission({
    required this.username,
    required this.madbId,
    required this.premiseId,
    required this.howsJsonString,
    required this.base64Image,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'madbId': madbId,
        'premiseId': premiseId,
        'howsJsonString': howsJsonString,
        'base64Image': base64Image,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp,
      };

  factory OfflineTaskSubmission.fromJson(Map<String, dynamic> json) =>
      OfflineTaskSubmission(
        username: json['username']?.toString() ?? '',
        madbId: json['madbId']?.toString() ?? '',
        premiseId: json['premiseId']?.toString() ?? '',
        howsJsonString: json['howsJsonString']?.toString() ?? '',
        base64Image: json['base64Image']?.toString() ?? '',
        latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
        longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
        timestamp: json['timestamp']?.toString() ?? '',
      );
}

class OfflineQueueService extends GetxService {
  static OfflineQueueService get to => Get.find<OfflineQueueService>();

  final _storage = GetStorage('offline_tasks_box');
  final _taskRepository = TaskRepository();
  StreamSubscription? _connectivitySubscription;

  RxList<OfflineTaskSubmission> queue = <OfflineTaskSubmission>[].obs;
  RxBool isSyncing = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadQueue();

    // Listen for connectivity transitions
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool hasConnection =
          results.any((result) => result != ConnectivityResult.none);
      if (hasConnection && queue.isNotEmpty && !isSyncing.value) {
        syncQueue();
      }
    });
  }

  void _loadQueue() {
    final List<dynamic>? stored = _storage.read<List<dynamic>>('tasks');
    if (stored != null) {
      queue.assignAll(stored
          .map((e) => OfflineTaskSubmission.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList());
    }
  }

  void _saveQueue() {
    _storage.write('tasks', queue.map((e) => e.toJson()).toList());
  }

  bool isTaskPendingSync(String madbId) {
    return queue.any((element) => element.madbId == madbId);
  }

  Future<void> enqueueTask(OfflineTaskSubmission task) async {
    // Avoid double entries
    if (queue.any((element) => element.madbId == task.madbId)) {
      return;
    }
    queue.add(task);
    _saveQueue();

    Get.snackbar(
      "Task Saved Offline",
      "Aapka task save ho gaya hai aur connection aane par sync ho jayega.",
      backgroundColor: Colors.orange.shade800,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> syncQueue() async {
    if (isSyncing.value || queue.isEmpty) return;

    try {
      isSyncing.value = true;
      debugPrint("🔄 Starting Offline Task Queue Sync (${queue.length} tasks)...");

      // Work on a copy of the queue to avoid modification during iteration
      final List<OfflineTaskSubmission> toSync = List.from(queue);

      for (final task in toSync) {
        debugPrint("📤 Syncing task ID: ${task.madbId}");
        try {
          final response = await _taskRepository.apiService.completeTask(
            username: task.username,
            madbId: task.madbId,
            premiseId: task.premiseId,
            howsJsonString: task.howsJsonString,
            precomputedBase64Image: task.base64Image,
            precomputedLat: task.latitude,
            precomputedLng: task.longitude,
          );

          if (response['status'] == true) {
            debugPrint("✅ Successfully synced task ID: ${task.madbId}");
            queue.removeWhere((element) => element.madbId == task.madbId);
            _saveQueue();
          } else {
            debugPrint("⚠️ Server returned false status for task ID: ${task.madbId}");
          }
        } catch (taskError) {
          debugPrint("❌ Failed to sync task ID ${task.madbId}: $taskError");
          // Break on network error so we don't spam requests when connection is unstable
          break;
        }
      }
    } finally {
      isSyncing.value = false;
    }
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }
}
