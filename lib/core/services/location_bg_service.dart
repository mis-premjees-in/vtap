// core/services/location_bg_service.dart
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'api_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
class LocationBgService {
  static const MethodChannel _nativeChannel = MethodChannel('com.premjees.vtap/location_service');

  static final _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    statusChangeDelayMs: 5000,
    allowMockLocations: false,
    printDevLog: kDebugMode,
  );

  static Future<void> initializeBackgroundTracking() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundServiceStart,
        autoStart: false, // Don't auto start before permissions are granted
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: 'task_channel',
        initialNotificationTitle: 'VTAP Workspace active monitoring',
        initialNotificationContent:
            'Silent geofence safety matrix is running...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false, // Don't auto start before permissions are granted
        onForeground: onBackgroundServiceStart,
        onBackground: (service) => false,
      ),
    );

    // Try starting if user already granted permissions in a previous session
    await startServiceIfPermissionsGranted();
  }

  static Future<void> startServiceIfPermissionsGranted() async {
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.always || permission == geo.LocationPermission.whileInUse) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await StorageService.addLog("Foreground App: Location permissions verified. Starting native Kotlin background service...");
          final bool? started = await _nativeChannel.invokeMethod<bool>('startService');
          await StorageService.addLog("Foreground App: Native Kotlin background service start returned: $started");
        } else {
          final service = FlutterBackgroundService();
          final isRunning = await service.isRunning();
          if (!isRunning) {
            await StorageService.addLog("Foreground App: Location permissions verified. Starting background service...");
            final started = await service.startService();
            await StorageService.addLog("Foreground App: Background service start call returned: $started");
          }
        }
      } else {
        await StorageService.addLog("Foreground App: Background service not started (Location permissions not granted yet).");
      }
    } catch (e) {
      await StorageService.addLog("Foreground App: Error starting background service: $e");
    }
  }

  static Future<void> stopNativeService() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await StorageService.addLog("Foreground App: Stopping native Kotlin background service...");
        final bool? stopped = await _nativeChannel.invokeMethod<bool>('stopService');
        await StorageService.addLog("Foreground App: Native Kotlin background service stop returned: $stopped");
      }
    } catch (e) {
      await StorageService.addLog("Foreground App: Error stopping native service: $e");
    }
  }

  @pragma('vm:entry-point')
  static void onBackgroundServiceStart(ServiceInstance service) async {
    // Register plugins for the background isolate
    DartPluginRegistrant.ensureInitialized();

    // Crucial initialization across separate background OS isolates
    final ApiService api = ApiService();
    final FlutterLocalNotificationsPlugin localBgNotifier =
        FlutterLocalNotificationsPlugin();

    String activeUsername = "";
    String currentStatus = "out";

    Future<void> startGeofencing(String username) async {
      try {
        _geofenceService.stop();
        await StorageService.addLog("Configuring geofencing for '$username'...");

        await StorageService.reload();
        // 1. Get latest whos_premise ID from server (no local cache dependency)
        final whosId = await StorageService.getWhosId();
        if (whosId.isEmpty) {
          await StorageService.addLog("Geofence Setup: No whosId found. Geofencing aborted.");
          return;
        }

        final whosResponse = await api.getTableData(
          tableName: "whos",
          username: username,
          customWhere: "whos_id='$whosId'",
        );

        if (whosResponse['status'] != true || whosResponse['response']?['Error'] != "0") {
          await StorageService.addLog("Geofence Setup: Failed to fetch whos table from server.");
          return;
        }

        final whosRecords = whosResponse['response']['Records'] as List;
        if (whosRecords.isEmpty) {
          await StorageService.addLog("Geofence Setup: No whos record found for whosId '$whosId'.");
          return;
        }

        final String whosPremiseId = whosRecords.first['whos_premise']?.toString() ?? '';
        if (whosPremiseId.isEmpty) {
          await StorageService.addLog("Geofence Setup: No whos_premise ID assigned on server.");
          return;
        }

        await StorageService.saveWhosPremise(whosPremiseId);

        // 2. Fetch all premises to find the match
        final premises = await api.getPremises(username: username);
        Map<String, dynamic>? matchingPremise;
        for (final p in premises) {
          if (p['premises_id']?.toString() == whosPremiseId) {
            matchingPremise = Map<String, dynamic>.from(p);
            break;
          }
        }

        if (matchingPremise == null) {
          await StorageService.addLog("Geofence Setup: Mapped premise ID '$whosPremiseId' not found in premises list.");
          return;
        }

        final latVal = matchingPremise['premises_latitude'];
        final lngVal = matchingPremise['premises_longitude'];
        final radVal = matchingPremise['premises_radius'];
        final String premiseName = matchingPremise['premises_name']?.toString() ?? 'Workspace';

        final List<Geofence> geofenceList = [];

        if (latVal != null && lngVal != null && radVal != null) {
          final double? lat = double.tryParse(latVal.toString());
          final double? lng = double.tryParse(lngVal.toString());
          final double? explicitRadius = double.tryParse(radVal.toString());

          if (lat != null && lng != null && explicitRadius != null) {
            // Save details to Storage
            await StorageService.savePremiseDetails(
              lat: lat,
              lng: lng,
              radius: explicitRadius,
              name: premiseName,
            );

            geofenceList.add(Geofence(
              id: matchingPremise['premises_id'].toString(),
              latitude: lat,
              longitude: lng,
              radius: [
                GeofenceRadius(id: 'radius_configured', length: explicitRadius)
              ],
            ));
          } else {
            await StorageService.addLog("Geofence Setup: Invalid database coordinates/radius values (Lat: $latVal, Lng: $lngVal, Radius: $radVal). Geofencing aborted.");
          }
        } else {
          await StorageService.addLog("Geofence Setup: Missing strict database values (Lat: $latVal, Lng: $lngVal, Radius: $radVal). Geofencing aborted.");
        }

        if (geofenceList.isNotEmpty) {
          _geofenceService.start(geofenceList);
          await StorageService.addLog("Geofence Setup: Started tracking for '$username' inside premise ID '$whosPremiseId' (Lat: $latVal, Lng: $lngVal, Radius: ${radVal}m).");
          if (kDebugMode) {
            print("Background geofencing service started for $username with assigned premise $whosPremiseId.");
          }
        }
      } catch (e) {
        await StorageService.addLog("Geofence Setup Error: $e");
        if (kDebugMode) {
          print("Error configuring geofences in background service: $e");
        }
      }
    }

    // 1. Initial State restoration if already logged in at startup
    await StorageService.reload();
    activeUsername = await StorageService.getUsername();
    currentStatus = await StorageService.getAttendanceStatus();
    await StorageService.addLog("Background service isolate started. Username: '$activeUsername', Status: '$currentStatus'");

    if (activeUsername.isNotEmpty) {
      await startGeofencing(activeUsername);
    }

    // Periodically sync punch status from API (every 3 minutes)
    Timer.periodic(const Duration(minutes: 3), (timer) async {
      await StorageService.reload();
      final String user = await StorageService.getUsername();
      if (user.isEmpty) return;

      try {
        final serverStatus = await api.getLastPunchStatus(username: user);
        final normalizedServerStatus = serverStatus.toLowerCase().trim();

        if (normalizedServerStatus != currentStatus) {
          await StorageService.addLog("Periodic Sync: Status mismatch detected! Local: '$currentStatus', Server: '$normalizedServerStatus'");
          currentStatus = normalizedServerStatus;
          await StorageService.saveAttendanceStatus(currentStatus);
          service.invoke('updatePunchState', {'status': currentStatus});

          if (currentStatus == 'in') {
            await startGeofencing(user);
          } else {
            _geofenceService.stop();
            await StorageService.addLog("Periodic Sync: Geofencing stopped because status is 'out'.");
            if (kDebugMode) {
              print("Background geofencing service stopped due to background punch-out detection.");
            }
          }
        }
      } catch (e) {
        await StorageService.addLog("Periodic Sync Error: $e");
        if (kDebugMode) {
          print("Background punch status periodic check failed: $e");
        }
      }
    });

    // 2. Set up background service event listeners
    service.on('startTracking').listen((event) async {
      await StorageService.reload();
      activeUsername = await StorageService.getUsername();
      currentStatus = await StorageService.getAttendanceStatus();
      await StorageService.addLog("Background Service Event: 'startTracking' (user='$activeUsername', status='$currentStatus')");
      if (activeUsername.isNotEmpty) {
        await startGeofencing(activeUsername);
      }
    });

    service.on('stopTracking').listen((event) async {
      _geofenceService.stop();
      activeUsername = "";
      currentStatus = "out";
      await StorageService.addLog("Background Service Event: 'stopTracking' (Stopped geofencing and reset states)");
      if (kDebugMode) {
        print("Background geofencing service stopped.");
      }
    });

    service.on('updatePunchStatus').listen((event) async {
      if (event != null && event['status'] != null) {
        currentStatus = event['status'].toString().toLowerCase().trim();
        await StorageService.addLog("Background Service Event: 'updatePunchStatus' to '$currentStatus'");
        if (kDebugMode) {
          print("Background geofencing service updated punch status to: $currentStatus");
        }
      }
    });

    _geofenceService.addGeofenceStatusChangeListener((
      Geofence geofence,
      GeofenceRadius geofenceRadius,
      GeofenceStatus geofenceStatus,
    ) {
      unawaited(() async {
        try {
          await StorageService.reload();
          final whosId = await StorageService.getWhosId();
          final token = await StorageService.getToken();

          await StorageService.addLog("Geofence Trigger: event=${geofenceStatus.toString().split('.').last}, userStatus='$currentStatus', premiseID='${geofence.id}'");

          if (geofenceStatus == GeofenceStatus.ENTER && currentStatus == 'out') {
            await StorageService.addLog("Geofence Action: ENTER zone detected. Initiating submitPunch(In) for user '$activeUsername'...");
            final success = await api.submitPunch(
              username: activeUsername,
              accessToken: token,
              type: "In",
              premiseId: geofence.id,
              whosId: whosId,
            );

            if (success) {
              currentStatus = 'in';
              await StorageService.saveAttendanceStatus('in');
              service.invoke('updatePunchState', {'status': 'in'});
              await StorageService.addLog("Geofence Action Success: Auto Punch-In succeeded on server.");

              await localBgNotifier.show(
                888,
                "Auto Punched In",
                "Aap assigned workspace boundary ke andar aa gaye hain. Aapka automatic IN mark ho chuka hai.",
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'task_channel',
                    'Task Reminders',
                    importance: Importance.max,
                    priority: Priority.high,
                    playSound: true,
                    visibility: NotificationVisibility.public,
                  ),
                ),
              );
            } else {
              await StorageService.addLog("Geofence Action Error: submitPunch(In) failed on server API.");
            }
          } else if (geofenceStatus == GeofenceStatus.EXIT && currentStatus == 'in') {
            await StorageService.addLog("Geofence Action: EXIT zone detected. Initiating submitPunch(Out) for user '$activeUsername'...");
            final success = await api.submitPunch(
              username: activeUsername,
              accessToken: token,
              type: "Out",
              premiseId: geofence.id,
              whosId: whosId,
            );

            if (success) {
              currentStatus = 'out';
              await StorageService.saveAttendanceStatus('out');
              service.invoke('updatePunchState', {'status': 'out'});
              await StorageService.addLog("Geofence Action Success: Auto Punch-Out succeeded on server.");

              await localBgNotifier.show(
                888,
                "Auto Punched Out",
                "Aap assigned workspace boundary se bahar nikal gaye hain. Aapka automatic OUT mark ho chuka hai.",
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'task_channel',
                    'Task Reminders',
                    importance: Importance.max,
                    priority: Priority.high,
                    playSound: true,
                    visibility: NotificationVisibility.public,
                  ),
                ),
              );
            } else {
              await StorageService.addLog("Geofence Action Error: submitPunch(Out) failed on server API.");
            }
          }
        } catch (e) {
          await StorageService.addLog("Geofence Action Failure: $e");
          if (kDebugMode) {
            print("Background loop callback analysis error: $e");
          }
        }
      }());
    } as GeofenceStatusChanged);
  }
}
