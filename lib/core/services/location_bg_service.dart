import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// 🔥 MAKE SURE THESE RELATIVE PATHS MATCH YOUR DIRECTORY EXACTLY
import 'api_service.dart';
import 'storage_service.dart';

class LocationBgService {
  static final _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    statusChangeDelayMs: 10000,
    allowMockLocations: false,
    printDevLog: true,
  );

  static Future<void> initializeBackgroundTracking() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundServiceStart,
        autoStart: true,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: 'task_channel',
        initialNotificationTitle: 'VTAP Attendance Sync',
        initialNotificationContent:
            'Monitoring assigned workspace boundaries...',

        // Removed the line causing 'Undefined name' error.
        // Android already reads this value directly from your AndroidManifest.xml!
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onBackgroundServiceStart,
        onBackground: (service) => false,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onBackgroundServiceStart(ServiceInstance service) async {
    await GetStorage.init();
    final ApiService api = ApiService();

    // 🔥 FIX: Bind the execution thread to an independent foreground instance container
    if (service is AndroidServiceInstance) {
      service
          .setAsForegroundService(); // Forces Android engine to prioritize this task

      // Intercept the stop request so the OS doesn't kill it when app UI is swiped away
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    // Pull credentials using your StorageService methods
    final String username = await StorageService.getUsername();
    final String token = await StorageService.getToken();
    final String whosId = await StorageService.getWhosId();

    if (username.isEmpty || token.isEmpty || whosId.isEmpty) {
      if (kDebugMode) {
        print(
            "Geofence execution aborted: Missing user authentication credentials.");
      }
      return;
    }

    try {
      // 1. Fetch live coordinates from your dynamic API
      final List premises = await api.getPremises(username: username);
      final List<Geofence> geofenceList = [];

      for (var p in premises) {
        if (p['latitude'] != null && p['longitude'] != null) {
          geofenceList.add(Geofence(
            id: p['premises_id'].toString(),
            latitude: double.parse(p['latitude'].toString()),
            longitude: double.parse(p['longitude'].toString()),
            radius: [GeofenceRadius(id: 'radius_100m', length: 100)],
          ));
        }
      }

      if (geofenceList.isEmpty) return;

      // 2. Start checking geofence crossing triggers
      // 2. Start checking geofence crossing triggers
      // 🔥 FIX: Callback function signature must be synchronous (void) to match GeofenceStatusChanged
      _geofenceService.addGeofenceStatusChangeListener((
        Geofence geofence,
        GeofenceRadius geofenceRadius,
        GeofenceStatus geofenceStatus,
      ) {
        // Run async operations inside the synchronous callback block cleanly
        unawaited(() async {
          try {
            // Fetch current localized baseline status parameter from backend API contract
            String statusCheck =
                await api.getLastPunchStatus(username: username);

            // ENTERING PREMISES -> AUTO PUNCH IN
            if (geofenceStatus == GeofenceStatus.ENTER &&
                statusCheck.toLowerCase() == 'out') {
              final response = await api.submitPunch(
                username: username,
                accessToken: token,
                type: "In",
                premiseId: geofence.id,
                whosId: whosId,
              );

              if (response == true) {
                await StorageService.saveAttendance(
                    status: "in", premiseName: geofence.id);
                if (kDebugMode) {
                  print(
                      "Successfully background auto-punched IN via Geofence boundary verification");
                }
              }
            }

            // EXITING PREMISES -> AUTO PUNCH OUT
            if (geofenceStatus == GeofenceStatus.EXIT &&
                statusCheck.toLowerCase() == 'in') {
              final response = await api.submitPunch(
                username: username,
                accessToken: token,
                type: "Out",
                premiseId: geofence.id,
                whosId: whosId,
              );

              if (response == true) {
                await StorageService.saveAttendance(
                    status: "out", premiseName: "");
                if (kDebugMode) {
                  print(
                      "Successfully background auto-punched OUT via Geofence boundary verification");
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print("Error tracking geofence state switch action: $e");
            }
          }
        }());
      } as GeofenceStatusChanged);
      _geofenceService.start(geofenceList).catchError((e) {
        if (kDebugMode) print("Geofence execution runtime crash: $e");
      });
    } catch (e) {
      if (kDebugMode) {
        print(
            "Failed initializing automated background tracking components: $e");
      }
    }
  }
}
