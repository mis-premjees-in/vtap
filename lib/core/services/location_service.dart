import 'package:geolocator/geolocator.dart';

class LocationService {
  // =====================================================
  // VALIDATE USER INSIDE PREMISE
  // =====================================================

  static Future<bool> validateUserInPremise(
    List<dynamic> premises,
  ) async {
    try {
      // ==========================
      // CHECK SERVICE ENABLED
      // ==========================

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return false;
      }

      // ==========================
      // CHECK PERMISSION
      // ==========================

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      // ==========================
      // GET CURRENT LOCATION
      // ==========================

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print(
        "CURRENT LOCATION => "
        "${position.latitude}, ${position.longitude}",
      );

      // ==========================
      // CHECK PREMISES
      // ==========================

      for (var premise in premises) {
        double lat = double.tryParse(
              premise['premises_latitude'].toString(),
            ) ??
            0.0;

        double lng = double.tryParse(
              premise['premises_longitude'].toString(),
            ) ??
            0.0;

        double radius = double.tryParse(
              premise['premises_radius'].toString(),
            ) ??
            100.0;

        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        print(
          "PREMISE => ${premise['premises_name']}",
        );

        print(
          "DISTANCE => $distance | ALLOWED => $radius",
        );

        if (distance <= radius) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print("LOCATION VALIDATION ERROR => $e");

      return false;
    }
  }
}
