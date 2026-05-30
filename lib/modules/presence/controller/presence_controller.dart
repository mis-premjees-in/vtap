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

      // 1. Fetch latest whos_premise ID from server (no local cache dependency)
      final whosId = await StorageService.getWhosId();
      if (whosId.isEmpty) {
        Get.snackbar("Error", "No profile mapping found (Missing whos_id).",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      final whosResponse = await _api.getTableData(
        tableName: "whos",
        username: username,
        customWhere: "whos_id='$whosId'",
      );

      if (whosResponse['status'] != true || whosResponse['response']?['Error'] != "0") {
        Get.snackbar("Error", "Failed to retrieve your profile details from the server.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      final whosRecords = whosResponse['response']['Records'] as List;
      if (whosRecords.isEmpty) {
        Get.snackbar("Error", "No profile records found on the server.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      final String whosPremiseId = whosRecords.first['whos_premise']?.toString() ?? '';
      if (whosPremiseId.isEmpty) {
        Get.snackbar("Error", "No workspace premise assigned to your profile on the server.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      // Save the fresh one to storage
      await StorageService.saveWhosPremise(whosPremiseId);

      // 2. Fetch all premises list and match by ID
      final premises = await _api.getPremises(username: username);
      Map<String, dynamic>? matchingPremise;
      for (final p in premises) {
        if (p['premises_id']?.toString() == whosPremiseId) {
          matchingPremise = Map<String, dynamic>.from(p);
          break;
        }
      }

      if (matchingPremise == null) {
        Get.snackbar("Error", "Your assigned workspace premise (ID: $whosPremiseId) was not found in the premises list.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      final latVal = matchingPremise['premises_latitude'];
      final lngVal = matchingPremise['premises_longitude'];
      final radVal = matchingPremise['premises_radius'];
      final String premiseName = matchingPremise['premises_name']?.toString() ?? 'Workspace';

      if (latVal == null || lngVal == null || radVal == null) {
        Get.snackbar("Error", "Assigned premise coordinates or radius are missing from the server.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      double? shopLat = double.tryParse(latVal.toString());
      double? shopLng = double.tryParse(lngVal.toString());
      double? allowedRadius = double.tryParse(radVal.toString());

      if (shopLat == null || shopLng == null || allowedRadius == null) {
        Get.snackbar("Error", "Assigned premise coordinates or radius are invalid on the server.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      // Save premise details to Storage for native background service usage
      await StorageService.savePremiseDetails(
        lat: shopLat,
        lng: shopLng,
        radius: allowedRadius,
        name: premiseName,
      );

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
        Get.snackbar("Location Error", "Hardware GPS issue. Verify device location is turned ON.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      double distance = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude, shopLat, shopLng);

      // 4. Manual Attendance must be within the database allowed radius
      if (distance <= allowedRadius) {
        String token = await StorageService.getToken();
        String whosId = await StorageService.getWhosId();

        if (username.trim().isEmpty || token.trim().isEmpty || whosId.trim().isEmpty) {
          Get.defaultDialog(
            title: "🔒 Configuration Error",
            middleText: "Aapke account ki profile registration details incomplete hain. Admin se contact karein.",
            textConfirm: "OK",
            confirmTextColor: Colors.white,
            buttonColor: Colors.redAccent,
            onConfirm: () => Get.back(),
          );
          return false;
        }

        final success = await _api.submitPunch(
          username: username,
          accessToken: token,
          type: forceType,
          premiseId: whosPremiseId,
          whosId: whosId,
        );

        if (success) {
          onPunchSuccess(forceType);
          Get.snackbar("Success", "Attendance registered successfully as ${forceType.toUpperCase()}",
              backgroundColor: Colors.green,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
          return true;
        }
        return false;
      } else {
        Get.defaultDialog(
          title: "Range Error",
          middleText: "Aap assigned shop ke center point se door hain.\n\nDistance: ${distance.toStringAsFixed(1)}m door.\n\nAttendance strictly center radius (${allowedRadius.toStringAsFixed(1)}m) ke andar allowed hai.",
          textConfirm: "Retry Check",
          buttonColor: Colors.deepOrange,
          confirmTextColor: Colors.white,
          onConfirm: () {
            Get.back();
            handlePunchToggle(username, forceType: forceType, onPunchSuccess: onPunchSuccess);
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
      // Fetch all premises list and match by ID
      final premises = await _api.getPremises(username: username);
      Map<String, dynamic>? matchingPremise;
      for (final p in premises) {
        if (p['premises_id']?.toString() == premiseId) {
          matchingPremise = Map<String, dynamic>.from(p);
          break;
        }
      }

      if (matchingPremise == null) {
        return false;
      }

      final latVal = matchingPremise['premises_latitude'];
      final lngVal = matchingPremise['premises_longitude'];
      final radVal = matchingPremise['premises_radius'];

      if (latVal == null || lngVal == null || radVal == null) {
        Get.snackbar(
          "Task Validation Error",
          "Workspace coordinates or radius missing in the database.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      double? shopLat = double.tryParse(latVal.toString());
      double? shopLng = double.tryParse(lngVal.toString());
      double? allowedTaskRadius = double.tryParse(radVal.toString());

      if (shopLat == null || shopLng == null || allowedTaskRadius == null) {
        Get.snackbar(
          "Task Validation Error",
          "Workspace coordinates or radius are invalid in the database.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

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

      double distance = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude, shopLat, shopLng);
      return distance <= allowedTaskRadius;
    } catch (_) {
      return false;
    }
  }
}
