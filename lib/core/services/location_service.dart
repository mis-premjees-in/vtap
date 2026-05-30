import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // =====================================================
  // REQUEST BACKGROUND LOCATION PERMISSION
  // =====================================================

  static Future<bool> requestBackgroundLocationPermission() async {
    try {
      // 1. First ensure foreground location is granted
      final foregroundGranted = await checkLocationPermission();
      if (!foregroundGranted) {
        return false;
      }

      // 2. Check current status of locationAlways (Background Location)
      var status = await Permission.locationAlways.status;
      if (status.isGranted) {
        return true;
      }

      // 3. If not granted, display explanation dialog first
      bool userAcceptedDialog = false;
      await Get.defaultDialog(
        title: "🔒 Background Location Needed",
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        titlePadding: const EdgeInsets.only(top: 20),
        middleText: "Auto Punch-In/Out features ko background mein chalane ke liye, location access ko settings mein 'Allow all the time' (Hamesha allow karein) select karna zaroori hai.\n\nAgle screen par permissions mein jaakar 'Allow all the time' option ko select karein.",
        textConfirm: "Settings Kholein",
        textCancel: "Cancel",
        confirmTextColor: Colors.white,
        cancelTextColor: Colors.grey,
        buttonColor: Colors.blueAccent,
        onConfirm: () {
          userAcceptedDialog = true;
          Get.back();
        },
        onCancel: () {
          userAcceptedDialog = false;
        },
      );

      if (!userAcceptedDialog) {
        return false;
      }

      // 4. Request background permission
      status = await Permission.locationAlways.request();
      if (status.isGranted) {
        return true;
      } else {
        Get.snackbar(
          "Permission Denied",
          "Background tracking lock hai jab tak aap 'Allow all the time' nahi select karte.",
          backgroundColor: Colors.amber,
          colorText: Colors.black87,
          duration: const Duration(seconds: 5),
        );
        return false;
      }
    } catch (e) {
      debugPrint("BACKGROUND PERMISSION ERROR => $e");
      return false;
    }
  }

  // =====================================================
  // CHECK LOCATION PERMISSION
  // =====================================================

  static Future<bool> checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("PERMISSION ERROR => $e");

      return false;
    }
  }

  // =====================================================
  // GET CURRENT POSITION
  // =====================================================

  static Future<Position> determinePosition() async {
    final hasPermission = await checkLocationPermission();

    if (!hasPermission) {
      throw Exception("Location permission denied");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  // =====================================================
  // GET MATCHED PREMISE
  // =====================================================

  static Future<Map<String, dynamic>?> getMatchedPremise(
    List<dynamic> premises,
  ) async {
    try {
      final position = await determinePosition();

      for (final premise in premises) {
        final latVal = premise['premises_latitude'];
        final lngVal = premise['premises_longitude'];
        final radVal = premise['premises_radius'];

        if (latVal == null || lngVal == null || radVal == null) {
          continue;
        }

        final double? lat = double.tryParse(latVal.toString());
        final double? lng = double.tryParse(lngVal.toString());
        final double? radius = double.tryParse(radVal.toString());

        if (lat == null || lng == null || radius == null) {
          continue;
        }

        final double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        debugPrint("PREMISE => ${premise['premises_name']}");

        debugPrint("DISTANCE => $distance");

        debugPrint("RADIUS => $radius");

        if (distance <= radius) {
          return Map<String, dynamic>.from(
            premise,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint("MATCH PREMISE ERROR => $e");

      return null;
    }
  }

  // =====================================================
  // VALIDATE INSIDE ANY PREMISE
  // =====================================================

  static Future<bool> validateUserInPremise(
    List<dynamic> premises,
  ) async {
    final matched = await getMatchedPremise(premises);

    return matched != null;
  }

  // =====================================================
  // VALIDATE SPECIFIC PREMISE
  // =====================================================

  static Future<bool> isInsidePremise(
    Map<String, dynamic> premise,
  ) async {
    try {
      final position = await determinePosition();

      final latVal = premise['premises_latitude'];
      final lngVal = premise['premises_longitude'];
      final radVal = premise['premises_radius'];

      if (latVal == null || lngVal == null || radVal == null) {
        return false;
      }

      final double? lat = double.tryParse(latVal.toString());
      final double? lng = double.tryParse(lngVal.toString());
      final double? radius = double.tryParse(radVal.toString());

      if (lat == null || lng == null || radius == null) {
        return false;
      }

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );

      debugPrint("========== PREMISE CHECK ==========");
      debugPrint("PREMISE => ${premise['premises_name']}");
      debugPrint("DISTANCE => $distance");
      debugPrint("RADIUS => $radius");
      debugPrint("===================================");

      return distance <= radius;
    } catch (e) {
      debugPrint("INSIDE PREMISE ERROR => $e");

      return false;
    }
  }
}
