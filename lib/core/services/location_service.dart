import 'package:geolocator/geolocator.dart';

class LocationService {
  // =====================================================
  // VALIDATE USER AGAINST FETCHED PREMISES
  // =====================================================
  static Future<bool> validateUserInPremise(List<dynamic> premises) async {
    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("LOCATION SERVICE DISABLED");
        return false;
      }

      // 2. Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("LOCATION PERMISSION DENIED");
        return false;
      }

      // 3. Get current high-accuracy position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      print(
          "CURRENT LOCATION => Lat: ${position.latitude}, Lng: ${position.longitude}");

      // 4. Iterate through premises list from database
      for (var premise in premises) {
        // Using your specific column names from the premises table
        double destLat =
            double.tryParse(premise['premises_latitude'].toString()) ?? 0.0;
        double destLng =
            double.tryParse(premise['premises_longitude'].toString()) ?? 0.0;

        // Use the dynamic radius from the database
        double allowedRadius =
            double.tryParse(premise['premises_radius'].toString()) ?? 10.0;

        // Calculate distance in meters
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destLat,
          destLng,
        );

        print(
            "Checking: ${premise['premise_name']} | Distance: $distance | Allowed: $allowedRadius");

        if (distance <= allowedRadius) {
          print("VALIDATED: Inside ${premise['premise_name']}");
          return true; // Match found
        }
      }

      print("VALIDATION FAILED: Not within any premise radius");
      return false;
    } catch (e) {
      print("LOCATION SERVICE ERROR => $e");
      return false;
    }
  }

  // =====================================================
  // GET CURRENT POSITION HELPER
  // =====================================================
  static Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // =====================================================
  // LEGACY HELPER (For Dashboard/Tasks)
  // If you want to use this for tasks, you should pass
  // the premises list here too.
  // =====================================================
  static Future<bool> canCompleteTask(List<dynamic> premises) async {
    return await validateUserInPremise(premises);
  }
}
