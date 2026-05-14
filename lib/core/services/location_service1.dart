import 'package:geolocator/geolocator.dart';

class LocationService1 {
  // =====================================================
  // OFFICE / SHOP LOCATION
  // =====================================================

  static const double officeLat = 30.911728;
  static const double officeLng = 77.095349;

  // =====================================================
  // ALLOWED RADIUS IN METERS
  // =====================================================

  static const double allowedDistance = 10;

  // =====================================================
  // CHECK USER CAN COMPLETE TASK
  // =====================================================

  static Future<bool> canCompleteTask() async {
    try {
      // =====================================================
      // LOCATION SERVICE
      // =====================================================

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        print("LOCATION SERVICE DISABLED");

        return false;
      }

      // =====================================================
      // PERMISSION
      // =====================================================

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("LOCATION PERMISSION DENIED");

        return false;
      }

      // =====================================================
      // GET CURRENT LOCATION
      // =====================================================

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      print(
        "CURRENT LOCATION => ${position.latitude}, ${position.longitude}",
      );

      // =====================================================
      // CALCULATE DISTANCE
      // =====================================================

      double distance = Geolocator.distanceBetween(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );

      print("DISTANCE => $distance");

      // =====================================================
      // RETURN TRUE IF INSIDE 10 METERS
      // =====================================================

      return distance <= allowedDistance;
    } catch (e) {
      print("LOCATION ERROR => $e");

      return false;
    }
  }
}
