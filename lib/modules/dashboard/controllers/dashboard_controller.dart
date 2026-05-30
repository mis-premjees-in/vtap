// modules/dashboard/controllers/dashboard_controller.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:vtap/core/services/notification_service.dart';
import 'package:vtap/modules/presence/controller/presence_controller.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/location_bg_service.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../data/models/task_model.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../routes/app_routes.dart';

class DashboardController extends GetxController {
  final ApiService _apiService = ApiService();
  final TaskRepository _taskRepository = TaskRepository();
  final OfflineQueueService _offlineQueueService = OfflineQueueService.to;
  final PresenceController _presenceController = Get.put(PresenceController());

  RxBool isLoading = false.obs;
  RxBool isPunching = false.obs;
  RxBool isHindi = false.obs;
  RxBool isAdmin = false.obs;
  final RxBool isSyncingCalendar = false.obs;

  // Track state safely using camel-case defaults matching your database logs
  RxString currentPunchStatus = "Out".obs;
  RxInt highlightedIndex = 0.obs;
  RxList<TaskModel> tasks = <TaskModel>[].obs;
  RxSet<String> completingTasks = <String>{}.obs;
  Rx<TaskModel?> reminderTask = Rx<TaskModel?>(null);

  Timer? highlightTimer;
  Timer? reminderTimer;

  RxInt activeTabIndex = 0.obs;

  void changeTab(int index) {
    activeTabIndex.value = index;
  }

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
    startHighlightAnimation();
    startReminderChecker();

    // Listen for background auto-punch status broadcasts
    if (!kIsWeb) {
      FlutterBackgroundService().on('updatePunchState').listen((event) async {
        if (event != null && event['status'] != null) {
          String updatedStatus = event['status'].toString().trim();
          await StorageService.addLog("Foreground App: Received 'updatePunchState' from background isolate ($updatedStatus)");
          _updateLocalPunchState(updatedStatus);
        }
      });
    }
  }

  Future<void> loadInitialData() async {
    try {
      isLoading.value = true;
      isAdmin.value = await StorageService.isAdmin();
      await loadPunchStatus();
      await fetchTasks(showLoader: false);
    } catch (e) {
      debugPrint("INITIALIZATION STEP SEVERE INTERCEPT => $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Helper utility to enforce correct casing updates
  // void _updateLocalPunchState(String serverRawStatus) {
  //   String normalized = serverRawStatus.toLowerCase().trim();
  //   if (normalized == "in") {
  //     currentPunchStatus.value = "In";
  //   } else {
  //     currentPunchStatus.value = "Out";
  //   }
  //   currentPunchStatus.refresh();
  //   debugPrint(
  //       "🎯 PUNCH STATE REALIZED IN CONTROLLER STACK => ${currentPunchStatus.value}");
  // }
  // =========================================================================
  // UTILITY: STABLE REACTIVE LOCAL STATE UPDATES
  // =========================================================================
  void _updateLocalPunchState(String serverCasingValue) {
    String normalized = serverCasingValue.toString().toLowerCase().trim();
    currentPunchStatus.value = normalized;
    currentPunchStatus
        .refresh(); // Forces binding observers to refresh layout view elements
  }

  // =========================================================================
  // INTERFACE ACTION TRIGGER (EXPLICIT UI DRIVEN INTENT HANDLER)
  // =========================================================================
  // Future<void> handlePunchAction() async {
  //   try {
  //     isPunching.value = true;
  //     final username = await StorageService.getUsername();
  //     if (username.isEmpty) return;

  //     // 1. Check what the current UI state reflects BEFORE executing database pipeline logic
  //     final String rawStatus = currentPunchStatus.value.toString().toLowerCase().trim();
  //     final bool currentlyPunchedIn = rawStatus == "in";

  //     // 2. Explicitly determine forced target state parameter to send to database
  //     final String targetForceType = currentlyPunchedIn ? "Out" : "In";

  //     debugPrint("📤 UI Triggered Action! Current State: '$rawStatus'. Sending Explicit Force Type: '$targetForceType'");

  //     // 3. Fire sequence tracking flow using direct parameterized tracking arguments
  //     await _presenceController.handlePunchToggle(
  //       username,
  //       forceType: targetForceType, // 🔥 Guarantees database receives correct uppercase state string!
  //       onPunchSuccess: (String liveStatusFromServer) {
  //         _updateLocalPunchState(liveStatusFromServer);
  //       },
  //     );
  //   } catch (e) {
  //     debugPrint("PUNCH INTERFACE ERROR => $e");
  //   } finally {
  //     isPunching.value = false;
  //     await fetchTasks(showLoader: false); // Refreshes task metrics list fields smoothly on finish
  //   }
  // }

  // =========================================================================
  // ATTENDANCE PIPELINE (SYNCHRONIZED ON TOGGLE COMPLETION)
  // ATTENDANCE PIPELINE WITH MASTER GEOLOCATION LOCKING (ANY PREMISE <= 5M)
  // =========================================================================
  Future<void> handlePunchAction() async {
    try {
      isPunching.value = true;
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      // 1. Check what the current UI state reflects BEFORE executing database pipeline logic
      final String rawStatus = currentPunchStatus.value.toString().toLowerCase().trim();
      final bool currentlyPunchedIn = rawStatus == "in";

      // 2. Explicitly determine forced target state parameter to send to database
      final String targetForceType = currentlyPunchedIn ? "Out" : "In";

      debugPrint("📤 UI Triggered Action! Current State: '$rawStatus'. Sending Explicit Force Type: '$targetForceType'");

      // 3. Delegate to the presence controller which coordinates geolocation validation
      await _presenceController.handlePunchToggle(
        username,
        forceType: targetForceType,
        onPunchSuccess: (String liveStatusFromServer) async {
          _updateLocalPunchState(liveStatusFromServer);

          // Persist the status for cross-isolate visibility
          await StorageService.saveAttendanceStatus(liveStatusFromServer);

           // Update the background service isolate dynamically
          if (!kIsWeb) {
            try {
              if (liveStatusFromServer.toLowerCase() == "in") {
                await LocationService.requestBackgroundLocationPermission();
              }
              await LocationBgService.startServiceIfPermissionsGranted();
              await StorageService.addLog("Foreground App: Syncing background tracking status to '$liveStatusFromServer'");
              FlutterBackgroundService().invoke('updatePunchStatus', {'status': liveStatusFromServer});
              if (liveStatusFromServer.toLowerCase() == "in") {
                await StorageService.addLog("Foreground App: Invoking startTracking on background service");
                FlutterBackgroundService().invoke('startTracking');
              } else {
                await StorageService.addLog("Foreground App: Invoking stopTracking on background service");
                FlutterBackgroundService().invoke('stopTracking');
                await LocationBgService.stopNativeService();
              }
            } catch (bgError) {
              await StorageService.addLog("Foreground App: Background tracking sync invoke failed: $bgError");
              debugPrint("Background service tracking sync failed: $bgError");
            }
          }
        },
      );
    } catch (e) {
      debugPrint("PUNCH ACTION FAILURE INTERCEPT => $e");
    } finally {
      isPunching.value = false;
      await fetchTasks(showLoader: false); // Refreshes task metrics list fields smoothly on finish
    }
  }

  Future<void> loadPunchStatus() async {
    try {
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      final status = await _apiService.getLastPunchStatus(username: username);
      _updateLocalPunchState(status);
    } catch (_) {
      currentPunchStatus.value = "Out"; // Fail-safe default
    }
  }

  // =========================================================================
  // EXCEPTION-SAFE TASK PIPELINE (PREVENTS INFINITE LOADING SCREEN)
  // =========================================================================
  Future<void> fetchTasks({bool showLoader = true}) async {
    try {
      if (showLoader) isLoading.value = true;
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      final mergedTasks = await _taskRepository.getTodayTasks(username);
      // Mark tasks that are pending offline sync as completed locally
      for (final task in mergedTasks) {
        if (_offlineQueueService.isTaskPendingSync(task.id)) {
          task.isCompleted = true;
        }
      }
      tasks.assignAll(mergedTasks);

      _scheduleAllLocalReminders();
      updateReminderTask();

      int incompleteIdx = tasks.indexWhere((e) => !e.isCompleted);
      highlightedIndex.value =
          incompleteIdx != -1 ? incompleteIdx.clamp(0, tasks.length - 1) : 0;

      // Auto Google Calendar Sync (silent) - Disabled for now
      // syncTasksToGoogleCalendar(silent: true);
    } catch (e) {
      debugPrint("CRITICAL TASKS PIPELINE FAILURE EXCEPTION INTERCEPTED => $e");
    } finally {
      isLoading.value = false; // Always ensures loader dismisses gracefully
    }
  }

  void _scheduleAllLocalReminders() async {
    if (kIsWeb) return;
    final now = DateTime.now();
    for (final task in tasks) {
      if (task.isCompleted || task.whenTime.isEmpty) continue;
      try {
        final split = task.whenTime.split(":");
        if (split.length < 2) continue;
        final taskDateTime = DateTime(now.year, now.month, now.day,
            int.parse(split[0]), int.parse(split[1]));
        await NotificationService.scheduleTaskReminder(
          id: task.id.toString().hashCode,
          title: isHindi.value ? task.taskHindi : task.taskEnglish,
          taskTime: taskDateTime,
          frequency: task.frequency,
        );
      } catch (_) {}
    }
  }

  Future<void> completeTask(TaskModel task, {File? imageFile}) async {
    try {
      // ✨ FIXED: Added case-insensitive normalization (.toLowerCase().trim())
      // This safely matches "In" or "in" and prevents the false "Attendance Required" dialog.
      debugPrint("current status ${currentPunchStatus.value.toLowerCase().trim()}");
      if (currentPunchStatus.value.toLowerCase().trim() != "in") {
        Get.defaultDialog(
          title: "🔒 Attendance Required",
          middleText:
              "Task complete karne ke liye pehle Punch-In karna zaroori hai. Kya aap abhi Punch-In karna chahte hain?",
          textCancel: "Cancel",
          textConfirm: "Punch-In Now",
          confirmTextColor: Colors.white,
          buttonColor: Colors.deepOrange,
          onConfirm: () async {
            Get.back();
            await handlePunchAction(); // Calls your newly updated location-hardened method
          },
        );
        return;
      }

      if (task.isCompleted || completingTasks.contains(task.id)) return;

      completingTasks.add(task.id);
      Get.dialog(
          const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange)),
          barrierDismissible: false);

      final username = await StorageService.getUsername();
      final whosPremiseId = await StorageService.getWhosPremise();
      final targetPremiseId = task.premiseId.isNotEmpty ? task.premiseId : whosPremiseId;

      // Check network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOffline =
          connectivityResult.contains(ConnectivityResult.none) ||
              connectivityResult.isEmpty;

      double latitude = 0.0;
      double longitude = 0.0;

      // Acquire location details (satellite GPS does not require internet)
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (_) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            latitude = lastKnown.latitude;
            longitude = lastKnown.longitude;
          }
        } catch (_) {}
      }

      // Proximity Check (only if online since we need registered premise bounds from API)
      if (!isOffline) {
        bool isInsideTaskPerimeter = await _presenceController
            .isUserWithinTaskRadius(username, targetPremiseId);
        if (!isInsideTaskPerimeter) {
          if (Get.isDialogOpen ?? false) Get.back();
          Get.defaultDialog(
            title: "📍 Location Error",
            middleText:
                "Aap is task ko complete nahi kar sakte kyunki aap shop ki assigned perimeter range se bahar hain.",
          );
          return;
        }
      }

      if (task.isUploadProofTask && imageFile == null) {
        imageFile = await pickImage();
        if (imageFile == null) {
          if (Get.isDialogOpen ?? false) Get.back();
          return;
        }
      }

      if (task.isExternalFormTask) {
        // Use LaunchMode.inAppBrowserView to keep user inside the app container
        await launchUrl(Uri.parse(task.howrUrl.trim()),
            mode: LaunchMode.inAppBrowserView);
        if (Get.isDialogOpen ?? false) Get.back();

        final bool? submitted = await Get.dialog<bool>(
          AlertDialog(
            title: const Text("Form Check"),
            content: const Text("Did you submit the form successfully?"),
            actions: [
              TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text("No")),
              ElevatedButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text("Yes")),
            ],
          ),
        );
        if (submitted != true) return;
        Get.dialog(const Center(child: CircularProgressIndicator()),
            barrierDismissible: false);
      }

      // If hard-offline, save directly to queue and simulate completion locally
      if (isOffline) {
        String base64Image = "";
        if (imageFile != null) {
          final compressedImage = await _apiService.compressImage(imageFile);
          List<int> imageBytes = await compressedImage.readAsBytes();
          base64Image = "data:image/jpg;base64,${base64Encode(imageBytes)}";
        }

        final submission = OfflineTaskSubmission(
          username: username,
          madbId: task.id,
          premiseId: targetPremiseId,
          howsJsonString: task.getHowsJsonString,
          base64Image: base64Image,
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now().toIso8601String(),
        );

        if (Get.isDialogOpen ?? false) Get.back();
        await _offlineQueueService.enqueueTask(submission);

        task.isCompleted = true;
        tasks.refresh();
        return;
      }

      // Try submitting online. Fallback to offline queue on network/connection exception
      try {
        final response = await _taskRepository.completeTask(
          username: username,
          madbId: task.id.toString(),
          premiseId: targetPremiseId,
          howsJsonString: task.getHowsJsonString,
          imageFile: imageFile,
        );

        if (Get.isDialogOpen ?? false) Get.back();

        if (response['status'] == true) {
          task.isCompleted = true;
          tasks.refresh();
          Get.snackbar("Success", "Task saved successfully",
              backgroundColor: Colors.green, colorText: Colors.white);
          await fetchTasks(showLoader: false);
        } else {
          Get.snackbar(
              "Error", response['response']?['Message'] ?? "Submission failed",
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } catch (networkError) {
        if (Get.isDialogOpen ?? false) Get.back();
        debugPrint("API completion error, enqueuing offline task: $networkError");

        String base64Image = "";
        if (imageFile != null) {
          final compressedImage = await _apiService.compressImage(imageFile);
          List<int> imageBytes = await compressedImage.readAsBytes();
          base64Image = "data:image/jpg;base64,${base64Encode(imageBytes)}";
        }

        final submission = OfflineTaskSubmission(
          username: username,
          madbId: task.id,
          premiseId: targetPremiseId,
          howsJsonString: task.getHowsJsonString,
          base64Image: base64Image,
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now().toIso8601String(),
        );

        await _offlineQueueService.enqueueTask(submission);
        task.isCompleted = true;
        tasks.refresh();
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      debugPrint("TASK ERROR => $e");
    } finally {
      completingTasks.remove(task.id);
    }
  }

  Future<void> logoutUser() async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    // Stop background tracking on logout
    if (!kIsWeb) {
      try {
        await StorageService.addLog("Foreground App: Stopping background service on logout");
        FlutterBackgroundService().invoke('stopTracking');
        await LocationBgService.stopNativeService();
      } catch (e) {
        await StorageService.addLog("Foreground App: Failed to stop background tracking on logout: $e");
        debugPrint("Failed to stop background tracking on logout: $e");
      }
    }

    await StorageService.clearAll();
    Get.offAllNamed(AppRoutes.login);
  }

  void toggleLanguage() {
    isHindi.toggle();
    tasks.refresh();
  }

  Future<File?> pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 50);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  void startHighlightAnimation() {
    highlightTimer?.cancel();
    highlightTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (tasks.isEmpty) return;
      highlightedIndex.value = (highlightedIndex.value + 1) % tasks.length;
    });
  }

  void startReminderChecker() {
    reminderTimer?.cancel();
    reminderTimer = Timer.periodic(
        const Duration(minutes: 1), (timer) => updateReminderTask());
  }

  void updateReminderTask() => reminderTask.value = getCurrentReminderTask();

  TaskModel? getCurrentReminderTask() {
    try {
      final now = DateTime.now();
      for (final task in tasks) {
        if (task.isCompleted || task.whenTime.isEmpty) continue;
        final split = task.whenTime.split(":");
        if (split.length < 2) continue;
        final taskTime = DateTime(now.year, now.month, now.day,
            int.parse(split[0]), int.parse(split[1]));
        if (now.difference(taskTime).inMinutes.abs() <= 15) return task;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    highlightTimer?.cancel();
    reminderTimer?.cancel();
    super.onClose();
  }

  Future<void> syncTasksToGoogleCalendar({bool silent = false}) async {
    try {
      if (!silent) isSyncingCalendar.value = true;
      String googleToken = await GoogleAuthService.getOrRefreshAccessToken();
      if (googleToken.isEmpty) {
        if (silent) return; // Silent execution returns immediately on missing credentials
        final user = await GoogleAuthService.signInWithGoogle();
        if (user == null) {
          Get.snackbar("Auth Error", "Google Authentication failed or was cancelled.",
              backgroundColor: Colors.red, colorText: Colors.white);
          return;
        }
        googleToken = await GoogleAuthService.getOrRefreshAccessToken();
      }

      if (googleToken.isEmpty) {
        if (!silent) {
          Get.snackbar("Auth Error", "Could not retrieve Google Access Token.",
              backgroundColor: Colors.red, colorText: Colors.white);
        }
        return;
      }

      int syncedCount = 0;
      for (final task in tasks) {
        if (task.isCompleted || task.whenTime.isEmpty) continue;

        final split = task.whenTime.split(":");
        if (split.length < 2) continue;
        final hour = int.parse(split[0]);
        final minute = int.parse(split[1]);

        final now = DateTime.now();
        final eventStart = DateTime(now.year, now.month, now.day, hour, minute);
        final eventEnd = eventStart.add(const Duration(minutes: 30));

        List<String> recurrence = [];
        final freq = task.frequency.toLowerCase().trim();
        if (freq == "daily") {
          recurrence.add("RRULE:FREQ=DAILY");
        } else if (freq == "weekly") {
          recurrence.add("RRULE:FREQ=WEEKLY");
        } else if (freq == "monthly") {
          recurrence.add("RRULE:FREQ=MONTHLY");
        } else {
          recurrence.add("RRULE:FREQ=DAILY");
        }

        final cleanId = "vtap${task.id.toLowerCase().replaceAll(RegExp(r'[^a-v0-9]'), '')}";

        final payload = {
          "id": cleanId,
          "summary": isHindi.value ? task.taskHindi : task.taskEnglish,
          "description": "VTAP Task Verification\nSession: ${task.whenSession}\nMethod: ${task.howrMethod}\nWhere: ${task.where}",
          "start": {
            "dateTime": eventStart.toUtc().toIso8601String().replaceAll('Z', '+00:00'),
            "timeZone": "UTC"
          },
          "end": {
            "dateTime": eventEnd.toUtc().toIso8601String().replaceAll('Z', '+00:00'),
            "timeZone": "UTC"
          },
          "recurrence": recurrence,
          "reminders": {
            "useDefault": false,
            "overrides": [
              {
                "method": "popup",
                "minutes": 5
              }
            ]
          }
        };

        final url = "https://www.googleapis.com/calendar/v3/calendars/primary/events/$cleanId";

        try {
          final response = await _apiService.dio.put(
            url,
            data: jsonEncode(payload),
            options: Options(
              headers: {
                "Authorization": "Bearer $googleToken",
                "Content-Type": "application/json",
              },
            ),
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            syncedCount++;
          }
        } catch (dioError) {
          if (dioError is DioException && dioError.response?.statusCode == 401) {
            await StorageService.saveGoogleAccessToken("");
            if (!silent) {
              Get.snackbar("Auth Expired", "Google Session expired. Please try syncing again to re-authenticate.",
                  backgroundColor: Colors.orange.shade800, colorText: Colors.white);
            }
            return;
          }
          debugPrint("Failed to sync task ${task.id} to Google Calendar: $dioError");
        }
      }

      if (!silent) {
        Get.snackbar("Google Calendar Sync", "$syncedCount tasks successfully synced to Google Calendar!",
            backgroundColor: Colors.green, colorText: Colors.white);
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar("Sync Error", "Google Calendar Sync failed: $e",
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } finally {
      if (!silent) isSyncingCalendar.value = false;
    }
  }
}
