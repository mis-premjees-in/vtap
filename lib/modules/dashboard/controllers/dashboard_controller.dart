// modules/dashboard/controllers/dashboard_controller.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtap/core/services/notification_service.dart';
import 'package:vtap/modules/presence/controller/presence_controller.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/models/task_model.dart';
import '../../../routes/app_routes.dart';
import 'package:geolocator/geolocator.dart';

class DashboardController extends GetxController {
  final ApiService _apiService = ApiService();
  final PresenceController _presenceController = Get.put(PresenceController());

  RxBool isLoading = false.obs;
  RxBool isPunching = false.obs;
  RxBool isHindi = false.obs;

  // Track state safely using camel-case defaults matching your database logs
  RxString currentPunchStatus = "Out".obs;
  RxInt highlightedIndex = 0.obs;
  RxList<TaskModel> tasks = <TaskModel>[].obs;
  RxSet<String> completingTasks = <String>{}.obs;
  Rx<TaskModel?> reminderTask = Rx<TaskModel?>(null);

  Timer? highlightTimer;
  Timer? reminderTimer;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
    startHighlightAnimation();
    startReminderChecker();

    // Listen for background auto-punch status broadcasts
    FlutterBackgroundService().on('updatePunchState').listen((event) {
      if (event != null && event['status'] != null) {
        String updatedStatus = event['status'].toString().trim();
        _updateLocalPunchState(updatedStatus);
      }
    });
  }

  Future<void> loadInitialData() async {
    try {
      isLoading.value = true;
      await loadPunchStatus();
      await fetchTasks(showLoader: false);
    } catch (e) {
      print("INITIALIZATION STEP SEVERE INTERCEPT => $e");
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
  //   print(
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

  //     print("📤 UI Triggered Action! Current State: '$rawStatus'. Sending Explicit Force Type: '$targetForceType'");

  //     // 3. Fire sequence tracking flow using direct parameterized tracking arguments
  //     await _presenceController.handlePunchToggle(
  //       username,
  //       forceType: targetForceType, // 🔥 Guarantees database receives correct uppercase state string!
  //       onPunchSuccess: (String liveStatusFromServer) {
  //         _updateLocalPunchState(liveStatusFromServer);
  //       },
  //     );
  //   } catch (e) {
  //     print("PUNCH INTERFACE ERROR => $e");
  //   } finally {
  //     isPunching.value = false;
  //     await fetchTasks(showLoader: false); // Refreshes task metrics list fields smoothly on finish
  //   }
  // }

  // =========================================================================
  // ATTENDANCE PIPELINE (SYNCHRONIZED ON TOGGLE COMPLETION)
  // =========================================================================
  // =========================================================================
  // ATTENDANCE PIPELINE (FORCING EXPLICIT "In" / "Out" DATABASE STRINGS)
  // =========================================================================
  // =========================================================================
  // ATTENDANCE PIPELINE WITH MASTER GEOLOCATION LOCKING (5 METERS)
  // =========================================================================
  // =========================================================================
  // ATTENDANCE PIPELINE WITH MASTER GEOLOCATION LOCKING (ANY PREMISE <= 5M)
  // =========================================================================
  Future<void> handlePunchAction() async {
    try {
      isPunching.value = true;
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      // 1. Check what the current UI state is BEFORE sending to database
      final String rawStatus =
          currentPunchStatus.value.toString().toLowerCase().trim();
      final bool currentlyPunchedIn = rawStatus == "in";

      // 2. Determine explicitly what to send to the database (with First Letter Capital)
      final String targetForceType = currentlyPunchedIn ? "Out" : "In";

      print(
          "📤 UI Action Triggered! Current state: '$rawStatus'. Sending Explicit Force Type: '$targetForceType'");

      // 3. FETCH REGISTERED PREMISES VIA THE CORE API
      List premises = await _apiService.getPremises(username: username);
      if (premises.isEmpty) {
        Get.snackbar("Error", "No registered premises found for your profile.");
        return;
      }

      // 4. GEOLOCATION PERMISSIONS VALIDATION SECURITY CHECK
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
              "Location Error", "Location permission dena zaroori hai.");
          return;
        }
      }

      // 5. CAPTURE HIGH ACCURACY CURRENT LOCATION
      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 7),
        );
      } catch (_) {
        currentPos = await Geolocator.getLastKnownPosition();
      }

      if (currentPos == null) {
        Get.snackbar("Location Error",
            "Aapka dynamic hardware GPS respond nahi kar raha hai. Kripya location toggle switch off/on karein.");
        return;
      }

      // 6. LOOP THROUGH ALL PREMISES TO CHECK IF USER IS WITHIN 5 METERS OF ANY PREMISE
      bool isInsideAnyPremise = false;
      var matchedPremise;
      double closestDistance = double.infinity;

      for (var premise in premises) {
        try {
          double shopLat =
              double.parse(premise['premises_latitude'].toString());
          double shopLng =
              double.parse(premise['premises_longitude'].toString());

          double distance = Geolocator.distanceBetween(
            currentPos.latitude,
            currentPos.longitude,
            shopLat,
            shopLng,
          );

          // Track the closest shop distance to display in the error dialog if all fail
          if (distance < closestDistance) {
            closestDistance = distance;
          }

          if (distance <= 10.0) {
            isInsideAnyPremise = true;
            matchedPremise = premise;
            debugPrint(
                "📍 Target Lock! Matched Premise: ${premise['premises_name']} at ${distance.toStringAsFixed(2)} meters");
            break; // Valid premise found, exit loop immediately
          }
        } catch (e) {
          print("Error checking individual premise coordinates: $e");
        }
      }

      // 7. STRICT RADIUS COUNTER LOCKOUT CONDITION VERIFICATION
      if (isInsideAnyPremise && matchedPremise != null) {
        String premiseId = matchedPremise['premises_id'].toString();

        // Pass the target state explicitly to the presence controller
        await _presenceController.handlePunchToggle(
          username,
          forceType: targetForceType, // 🔥 Guarantees correct casing
          onPunchSuccess: (String liveStatusFromServer) {
            _updateLocalPunchState(liveStatusFromServer);
          },
        );
      } else {
        // Render range error warning modal showing the closest distance found
        Get.defaultDialog(
          title: "Location Range Error",
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Icon(Icons.location_off,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  "Aap kisi bhi assigned shop ke center point ke pass nahi hain.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  "Closest Shop Distance: ${closestDistance.toStringAsFixed(1)} meters door hain.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  "Attendance strictly counter ke pass (5 meters ke andar) hi mark ho sakti hai. Kripya check karein ki aapka GPS Mode high accuracy par set hai.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
          textConfirm: "Retry Sync",
          confirmTextColor: Colors.white,
          buttonColor: Colors.deepOrange,
          onConfirm: () {
            Get.back();
            handlePunchAction(); // Re-trigger the accurate check cleanly
          },
          textCancel: "Dismiss",
          cancelTextColor: Colors.black87,
        );
      }
    } catch (e) {
      print("PUNCH ACTION FAILURE INTERCEPT => $e");
    } finally {
      isPunching.value = false;
      await fetchTasks(
          showLoader: false); // Automatically refreshes list variables
    }
  }

  Future<void> loadPunchStatus() async {
    try {
      final username = await StorageService.getUsername();
      if (username.isEmpty) return;

      final status = await _apiService.getLastPunchStatus(username: username);
      if (status != null) {
        _updateLocalPunchState(status.toString());
      }
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

      final dynamic masterResponse =
          await _apiService.getTasks(username: username);
      final dynamic completedResponse =
          await _apiService.getTodayCompletedTasks(username: username);

      final Set<String> todayCompletedMadbIds = {};
      final Map<String, String> utedbHowsMap = {};
      final now = DateTime.now();
      final String todayDateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Safe evaluation array extraction for completed entries
      List<dynamic> completedRecords = [];
      if (completedResponse != null) {
        if (completedResponse is List) {
          completedRecords = completedResponse;
        } else if (completedResponse is Map &&
            completedResponse['response']?['Records'] is List) {
          completedRecords = completedResponse['response']['Records'];
        }
      }

      for (final item in completedRecords) {
        if (item is Map) {
          String createdDate = item['utedb_created']?.toString() ?? "";
          if (createdDate.startsWith(todayDateStr)) {
            String mid = item['utedb_madb']?.toString() ?? "";
            if (mid.isNotEmpty) {
              todayCompletedMadbIds.add(mid);
              if (item['utedb_hows1'] != null) {
                utedbHowsMap[mid] = item['utedb_hows1'].toString();
              }
            }
          }
        }
      }

      // Safe evaluation array extraction for master records
      List<dynamic> masterRecords = [];
      if (masterResponse != null) {
        if (masterResponse is List) {
          masterRecords = masterResponse;
        } else if (masterResponse is Map &&
            masterResponse['response']?['Records'] is List) {
          masterRecords = masterResponse['response']['Records'];
        }
      }

      List<TaskModel> mergedTasks = [];
      for (final item in masterRecords) {
        try {
          if (item is Map) {
            Map<String, dynamic> taskData =
                item.map((k, v) => MapEntry(k.toString(), v));
            String tid = taskData['madb_id']?.toString() ?? "";

            if (tid.isNotEmpty) {
              bool isDone = todayCompletedMadbIds.contains(tid);
              if (isDone && utedbHowsMap.containsKey(tid)) {
                taskData['utedb_hows1'] = utedbHowsMap[tid];
              }

              final task = TaskModel.fromJson(taskData);
              task.isCompleted = isDone;
              mergedTasks.add(task);
            }
          }
        } catch (innerMappingError) {
          print(
              "CORRUPTED RECORD ROW SKIPPED CORRECTION => $innerMappingError");
        }
      }

      mergedTasks.sort((a, b) =>
          a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1));
      tasks.assignAll(mergedTasks);

      _scheduleAllLocalReminders();
      updateReminderTask();

      int incompleteIdx = tasks.indexWhere((e) => !e.isCompleted);
      highlightedIndex.value =
          incompleteIdx != -1 ? incompleteIdx.clamp(0, tasks.length - 1) : 0;
    } catch (e) {
      print("CRITICAL TASKS PIPELINE FAILURE EXCEPTION INTERCEPTED => $e");
    } finally {
      isLoading.value = false; // Always ensures loader dismisses gracefully
    }
  }

  void _scheduleAllLocalReminders() async {
    final now = DateTime.now();
    for (final task in tasks) {
      if (task.isCompleted || task.whenTime.isEmpty) continue;
      try {
        final split = task.whenTime.split(":");
        if (split.length < 2) continue;
        final taskDateTime = DateTime(now.year, now.month, now.day,
            int.parse(split[0]), int.parse(split[1]));
        await NotificationService.scheduleTaskReminder(
          task.id.toString().hashCode,
          isHindi.value ? task.taskHindi : task.taskEnglish,
          taskDateTime,
        );
      } catch (_) {}
    }
  }

  Future<void> completeTask(TaskModel task) async {
    try {
      // ✨ FIXED: Added case-insensitive normalization (.toLowerCase().trim())
      // This safely matches "In" or "in" and prevents the false "Attendance Required" dialog.
      print("current status ${currentPunchStatus.value.toLowerCase().trim()}");
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

      bool isInsideTaskPerimeter = await _presenceController
          .isUserWithinTaskRadius(username, task.premiseId);
      if (!isInsideTaskPerimeter) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.defaultDialog(
          title: "📍 Location Error",
          middleText:
              "Aap is task ko complete nahi kar sakte kyunki aap shop ki assigned perimeter range se bahar hain.",
        );
        return;
      }

      File? imageFile;
      if (task.howrMethod.toLowerCase().contains("upload") ||
          task.howrMethod.toLowerCase().contains("image")) {
        imageFile = await pickImage();
        if (imageFile == null) {
          if (Get.isDialogOpen ?? false) Get.back();
          return;
        }
      }

      if (task.howrUrl.trim().isNotEmpty) {
        await launchUrl(Uri.parse(task.howrUrl.trim()),
            mode: LaunchMode.externalApplication);
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

      final response = await _apiService.completeTask(
        username: username,
        madbId: task.id.toString(),
        premiseId: task.premiseId,
        howsJsonString: task.getHowsJsonString,
        imageFile: imageFile,
      );

      if (Get.isDialogOpen ?? false) Get.back();

      if (response != null && response['status'] == true) {
        task.isCompleted = true;
        tasks.refresh();
        Get.snackbar("Success", "Task saved successfully",
            backgroundColor: Colors.green, colorText: Colors.white);
        await fetchTasks(showLoader: false);
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      print("TASK ERROR => $e");
    } finally {
      completingTasks.remove(task.id);
    }
  }

  Future<void> logoutUser() async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
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
}
