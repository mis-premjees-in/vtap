import 'dart:math';

import 'package:geolocator/geolocator.dart';

class LocationService {
  // ======================================================
  // GET CURRENT LOCATION
  // ======================================================

  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // GPS ON?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception("Location service disabled");
    }

    // PERMISSION
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied forever");
    }

    if (permission == LocationPermission.denied) {
      throw Exception("Location permission denied");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  // ======================================================
  // VALIDATE USER INSIDE PREMISE
  // ======================================================

  static Future<bool> validateUserInPremise(
    List<dynamic> premises,
  ) async {
    try {
      final position = await getCurrentLocation();

      print(
        "CURRENT LOCATION => "
        "${position.latitude}, ${position.longitude}",
      );

      for (var premise in premises) {
        final lat = double.tryParse(
              premise['premises_latitude'].toString(),
            ) ??
            0.0;

        final lng = double.tryParse(
              premise['premises_longitude'].toString(),
            ) ??
            0.0;

        final radius = double.tryParse(
              premise['premises_radius'].toString(),
            ) ??
            50.0;

        final name = premise['premises_name'].toString();

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        print(
          "Checking => $name | "
          "Distance => $distance | "
          "Allowed => $radius",
        );

        if (distance <= radius) {
          print("VALID PREMISE => $name");

          return true;
        }
      }

      return false;
    } catch (e) {
      print("LOCATION VALIDATION ERROR => $e");

      return false;
    }
  }

  // ======================================================
  // DISTANCE CALCULATOR
  // ======================================================

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;

    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a));
  }
}
