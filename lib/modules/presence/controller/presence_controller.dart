// modules/dashboard/controllers/presence_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';

class PresenceController extends GetxController {
  final ApiService _api = ApiService();
  RxBool isLoading = false.obs;

  // =========================================================================
  // CONDITION 1: MANUAL ATTENDANCE PUNCH (LOOPS ALL PREMISES ON-BY-ONE)
  // =========================================================================
  // modules/dashboard/controllers/presence_controller.dart

  // Future<bool> handlePunchToggle(
  //   String username, {
  //   required Function(String) onPunchSuccess,
  //   String? forceType, // 👈 Added optional explicit parameter
  // }) async {
  //   try {
  //     isLoading.value = true;

  //     // 1. Fetch live status from server
  //     String networkStatus = await _api.getLastPunchStatus(username: username);
  //     String cleanCurrentStatus = networkStatus.toLowerCase().trim();

  //     // Determine target operation: Use forceType if provided, otherwise toggle standardly
  //     String nextType =
  //         forceType ?? (cleanCurrentStatus == "in" ? "Out" : "In");

  //     // Double-check: If we are forcing an "In" punch but the user is ALREADY punched in, return early
  //     if (forceType == "In" && cleanCurrentStatus == "in") {
  //       onPunchSuccess("in");
  //       return true;
  //     }

  //     // 2. Fetch all available premises
  //     List premises = await _api.getPremises(username: username);
  //     if (premises.isEmpty) {
  //       Get.snackbar("Error", "No registered premises found for your profile.",
  //           backgroundColor: Colors.red, colorText: Colors.white);
  //       return false;
  //     }

  //     // 3. Capture location coordinates
  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied) {
  //       permission = await Geolocator.requestPermission();
  //       if (permission == LocationPermission.denied) return false;
  //     }

  //     Position? currentPos;
  //     try {
  //       currentPos = await Geolocator.getCurrentPosition(
  //         desiredAccuracy: LocationAccuracy.high,
  //         timeLimit: const Duration(seconds: 5),
  //       );
  //     } catch (_) {
  //       currentPos = await Geolocator.getLastKnownPosition();
  //     }

  //     if (currentPos == null) {
  //       Get.snackbar(
  //           "Location Error", "Could not capture your current GPS coordinates.",
  //           backgroundColor: Colors.red, colorText: Colors.white);
  //       return false;
  //     }

  //     // Loop through all premises to find the closest one
  //     var matchedClosestPremise;
  //     double shortestDistance = double.maxFinite;
  //     double configuredAllowedRadius = 50.0;

  //     for (var premise in premises) {
  //       try {
  //         double shopLat =
  //             double.parse(premise['premises_latitude'].toString());
  //         double shopLng =
  //             double.parse(premise['premises_longitude'].toString());
  //         double currentDistance = Geolocator.distanceBetween(
  //             currentPos.latitude, currentPos.longitude, shopLat, shopLng);

  //         if (currentDistance < shortestDistance) {
  //           shortestDistance = currentDistance;
  //           matchedClosestPremise = premise;
  //           configuredAllowedRadius =
  //               double.tryParse(premise['premises_radius'].toString()) ?? 50.0;
  //         }
  //       } catch (_) {}
  //     }

  //     if (matchedClosestPremise == null) return false;

  //     String selectedPremiseId =
  //         matchedClosestPremise['premises_id'].toString();
  //     String selectedPremiseName =
  //         matchedClosestPremise['premises_name'].toString();

  //     // Geofence lock check if performing a Punch In operation
  //     if (nextType == "In") {
  //       if (shortestDistance > configuredAllowedRadius) {
  //         Get.snackbar(
  //           "Access Locked",
  //           "Aap range se bahar hain!\nNearest Premise: $selectedPremiseName\nDistance: ${shortestDistance.toStringAsFixed(1)}m away (Allowed: ${configuredAllowedRadius}m)",
  //           backgroundColor: Colors.redAccent,
  //           colorText: Colors.white,
  //         );
  //         return false;
  //       }
  //     }

  //     String whosId = await StorageService.getWhosId();
  //     String token = await StorageService.getToken();

  //     final success = await _api.submitPunch(
  //       username: username,
  //       accessToken: token,
  //       type: nextType, // Safe target parameter
  //       premiseId: selectedPremiseId,
  //       whosId: whosId,
  //     );

  //     if (success) {
  //       String confirmedNewStatus = nextType.toLowerCase().trim();
  //       onPunchSuccess(confirmedNewStatus);
  //       Get.snackbar(
  //         "Success",
  //         "Punch-$nextType Successful at $selectedPremiseName!",
  //         backgroundColor: Colors.green,
  //         colorText: Colors.white,
  //       );
  //       return true;
  //     }
  //     return false;
  //   } catch (e) {
  //     Get.snackbar("System Failure", e.toString(),
  //         backgroundColor: Colors.red, colorText: Colors.white);
  //     return false;
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }
// =========================================================================
  // CONDITION 1: MANUAL ATTENDANCE PUNCH (STRICT 5-METER ZONE LOCK ON ANY PREMISE)
  // =========================================================================
  Future<bool> handlePunchToggle(
    String username, {
    required String forceType,
    required Function(String) onPunchSuccess,
  }) async {
    try {
      isLoading.value = true;

      // 1. USE EXPLICIT FORCE TYPE PASSED DIRECTLY FROM DASHBOARD VIEW FLOW
      String nextType = forceType;

      // 2. FETCH LIVE PREMISES FROM SERVER
      List premises = await _api.getPremises(username: username);
      if (premises.isEmpty) {
        Get.snackbar("Error", "No registered premises found for your profile.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 3. FETCH HIGH ACCURACY GPS COORDINATES
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
            "Hardware GPS issue. Verify device location is turned ON.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      // 4. SCAN THROUGH ALL PREMISES TO CHECK IF USER IS WITHIN 5 METERS
      bool isWithinAnyPremise = false;
      var matchedPremise;
      double closestDistance = double.infinity;

      for (var premise in premises) {
        try {
          double shopLat =
              double.parse(premise['premises_latitude'].toString());
          double shopLng =
              double.parse(premise['premises_longitude'].toString());

          double distance = Geolocator.distanceBetween(
              currentPos.latitude, currentPos.longitude, shopLat, shopLng);

          if (distance < closestDistance) {
            closestDistance = distance;
          }

          if (distance <= 5.0) {
            isWithinAnyPremise = true;
            matchedPremise = premise;
            break; // Target premise found, exit loop immediately
          }
        } catch (e) {
          debugPrint("Premise parsing sequence skip error: $e");
        }
      }

      // 5. ENFORCE RADIUS PERIMETER BOUNDARY CONDITION MATCH
      if (isWithinAnyPremise && matchedPremise != null) {
        String premiseId = matchedPremise['premises_id'].toString();
        String token = await StorageService.getToken();
        String whosId = await StorageService.getWhosId();

        // 6. SUBMIT ENFORCED CASING VALUE DIRECTLY TO SERVER
        final success = await _api.submitPunch(
          username: username,
          accessToken: token,
          type:
              nextType, // Sends exact "In" or "Out" matching DB casing requirements
          premiseId: premiseId,
          whosId: whosId,
        );

        if (success) {
          // Trigger the completion callback to sync foreground controller state
          onPunchSuccess(nextType);

          Get.snackbar("Success",
              "Attendance registered successfully as ${nextType.toUpperCase()}",
              backgroundColor: Colors.green,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
          return true;
        }
        return false;
      } else {
        Get.defaultDialog(
          title: "Range Error",
          middleText:
              "Aap kisi bhi assigned shop ke center point ke pass nahi hain.\n\nClosest Premise: ${closestDistance.toStringAsFixed(1)}m door.\n\nAttendance strictly counter radius (5m) ke andar allowed hai.",
          textConfirm: "Retry Check",
          buttonColor: Colors.deepOrange,
          confirmTextColor: Colors.white,
          onConfirm: () {
            Get.back();
            handlePunchToggle(username,
                forceType: forceType, onPunchSuccess: onPunchSuccess);
          },
        );
        return false;
      }
    } catch (e) {
      Get.snackbar("Error", "Punch processing failed: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
  // CONDITION 2: TASK COMPLETION RADIUS CHECK (REMAINS STABLE FOR TASKS)
  // =========================================================================
  Future<bool> isUserWithinTaskRadius(String username, String premiseId) async {
    try {
      List premises = await _api.getPremises(username: username);
      if (premises.isEmpty) return false;

      var activePremise = premises.firstWhere(
        (p) => p['premises_id'].toString() == premiseId.toString(),
        orElse: () => null,
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

      if (activePremise == null) {
        for (var premise in premises) {
          double shopLat =
              double.parse(premise['premises_latitude'].toString());
          double shopLng =
              double.parse(premise['premises_longitude'].toString());
          double radius =
              double.tryParse(premise['premises_radius'].toString()) ?? 50.0;
          double distance = Geolocator.distanceBetween(
              currentPos.latitude, currentPos.longitude, shopLat, shopLng);
          if (distance <= radius) return true;
        }
        return false;
      }

      double shopLat =
          double.parse(activePremise['premises_latitude'].toString());
      double shopLng =
          double.parse(activePremise['premises_longitude'].toString());
      double allowedTaskRadius =
          double.tryParse(activePremise['premises_radius'].toString()) ?? 50.0;

      double distance = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude, shopLat, shopLng);
      return distance <= allowedTaskRadius;
    } catch (_) {
      return false;
    }
  }
}
