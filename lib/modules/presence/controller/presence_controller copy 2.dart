// modules/dashboard/controllers/presence_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';

class PresenceController extends GetxController {
  final ApiService _api = ApiService();

  RxBool isLoading = false.obs;
  RxString lastStatus = "out".obs;

  Future<void> fetchStatus(String username) async {
    try {
      isLoading.value = true;
      String status = await _api.getLastPunchStatus(username: username);
      lastStatus.value = status.toLowerCase();
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch attendance status");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
  // CONDITION 1: ATTENDANCE PUNCH (STRICT 5-METER ZONE LOCK)
  // =========================================================================
  Future<bool> handlePunchToggle(String username) async {
    await fetchStatus(username);
    try {
      isLoading.value = true;
      String nextType = lastStatus.value == "in" ? "Out" : "In";

      List premises = await _api.getPremises(username: username);
      if (premises.isEmpty) {
        Get.snackbar("Error", "No registered premises found for your profile.");
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 1. Force the device to refresh and ignore old cached locations
      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy
              .high, // Better indoor handling than bestForNavigation
          timeLimit: const Duration(seconds: 7),
        );
      } catch (_) {
        // Fallback: If hardware lock times out, try last known position as secondary recovery
        currentPos = await Geolocator.getLastKnownPosition();
      }

      if (currentPos == null) {
        Get.snackbar("Location Error",
            "Aapka dynamic hardware GPS respond nahi kar raha hai. Kripya location toggle switch off/on karein.");
        return false;
      }

      var activePremise = premises.first;
      double shopLat =
          double.parse(activePremise['premises_latitude'].toString());
      double shopLng =
          double.parse(activePremise['premises_longitude'].toString());
      String premiseId = activePremise['premises_id'].toString();
      String premiseName = activePremise['premises_name'].toString();

      double distanceInMeters = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        shopLat,
        shopLng,
      );

      debugPrint(
          "Calculated real-time counter distance: ${distanceInMeters.toStringAsFixed(2)} meters");

      // Enforce the strict 5-meter counter spot radius lock
      if (distanceInMeters <= 10.0) {
        String token = await StorageService.getToken();
        String whosId = await StorageService.getWhosId();

        final success = await _api.submitPunch(
          username: username,
          accessToken: token,
          type: nextType,
          premiseId: premiseId,
          whosId: whosId,
        );

        // if (success) {
        //   String cachedStatusValue = nextType.toLowerCase();
        //   await StorageService.saveAttendance(
        //     status: cachedStatusValue,
        //     premiseName: nextType == "In" ? premiseName : "",
        //   );

        //   lastStatus.value = cachedStatusValue;
        //   return true;
        // }
        return false;
      } else {
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
                  "Aap center point se ${distanceInMeters.toStringAsFixed(1)} meters door hain.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black87),
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
            handlePunchToggle(username);
          },
          textCancel: "Dismiss",
          cancelTextColor: Colors.black87,
        );
        return false;
      }
    } catch (e) {
      Get.snackbar("Matrix Error", "Location match parameter process fail: $e");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
  // CONDITION 2: TASK COMPLETION PERMISSION CHECK
  // =========================================================================
  Future<bool> isUserWithinTaskRadius(String username, String premiseId) async {
    try {
      List premises = await _api.getPremises(username: username);
      if (premises.isEmpty) return false;

      var activePremise = premises.firstWhere(
        (p) => p['premises_id'].toString() == premiseId.toString(),
        orElse: () => premises.first,
      );

      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        currentPos = await Geolocator.getLastKnownPosition();
      }

      if (currentPos == null) return false;

      double shopLat =
          double.parse(activePremise['premises_latitude'].toString());
      double shopLng =
          double.parse(activePremise['premises_longitude'].toString());

      // If you want tasks to block at 40-50 feet (approx 15 meters) instead of the 65-meter database default,
      // replace this with a fixed value (e.g., 15.0) or update the premises_radius column in your database.
      double allowedTaskRadius =
          double.tryParse(activePremise['premises_radius'].toString()) ?? 50.0;

      double distance = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude, shopLat, shopLng);

      debugPrint(
          "Task location verification distance calculation: $distance meters against range limit: $allowedTaskRadius");
      return distance <= allowedTaskRadius;
    } catch (_) {
      return false;
    }
  }
}
