// core/services/location_bg_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';
import 'storage_service.dart';

class LocationBgService {
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
        autoStart: true,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: 'task_channel',
        initialNotificationTitle: 'VTAP Workspace active monitoring',
        initialNotificationContent:
            'Silent geofence safety matrix is running...',
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
    // Crucial initialization across separate background OS isolates
    await GetStorage.init();
    final ApiService api = ApiService();
    final FlutterLocalNotificationsPlugin localBgNotifier =
        FlutterLocalNotificationsPlugin();

    // Fallback checking strategy to preserve key information across storage layers
    final box = GetStorage();
    String username = box.read('username') ?? "";

    if (username.isEmpty) {
      // Secondary attempt to pull via structural key bindings
      username = await StorageService.getUsername();
      if (username.isEmpty) {
        if (kDebugMode)
          print("Geofencing background sequence aborted: User key data empty.");
        return;
      }
    }

    try {
      final List premises = await api.getPremises(username: username);
      final List<Geofence> geofenceList = [];

      for (var p in premises) {
        final latVal = p['premises_latitude'];
        final lngVal = p['premises_longitude'];
        final radVal = p['premises_radius'];

        if (latVal != null && lngVal != null) {
          double explicitRadius = double.tryParse(radVal.toString()) ?? 30.0;

          geofenceList.add(Geofence(
            id: p['premises_id'].toString(),
            latitude: double.parse(latVal.toString()),
            longitude: double.parse(lngVal.toString()),
            radius: [
              GeofenceRadius(id: 'radius_configured', length: explicitRadius)
            ],
          ));
        }
      }

      if (geofenceList.isEmpty) return;

      _geofenceService.addGeofenceStatusChangeListener((
        Geofence geofence,
        GeofenceRadius geofenceRadius,
        GeofenceStatus geofenceStatus,
      ) {
        unawaited(() async {
          try {
            String localStatus = (box.read('attendance_status') ?? 'out')
                .toString()
                .trim()
                .toLowerCase();

            // EXIT BREACH ALERT REMINDER
            if (geofenceStatus == GeofenceStatus.EXIT && localStatus == 'in') {
              await localBgNotifier.show(
                888,
                "Premises Perimeter Exited",
                "Aap assigned workspace boundary range se bahar nikal gaye hain! Kripya workspace me lautein ya manual punch complete karein.",
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
            }
          } catch (e) {
            if (kDebugMode)
              print("Background loop callback analysis error: $e");
          }
        }());
      } as GeofenceStatusChanged);

      _geofenceService.start(geofenceList);
    } catch (e) {
      if (kDebugMode)
        print("Background geofence engine configuration crashed: $e");
    }
  }
}
