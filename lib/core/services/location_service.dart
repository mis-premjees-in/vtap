import 'package:geolocator/geolocator.dart';

class LocationService {
  // =====================================================
  // GET MATCHED PREMISE
  // =====================================================

  static Future<Map<String, dynamic>?> getMatchedPremise(
    List<dynamic> premises,
  ) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      for (var premise in premises) {
        final double lat = double.tryParse(
              premise['premises_latitude'].toString(),
            ) ??
            0.0;

        final double lng = double.tryParse(
              premise['premises_longitude'].toString(),
            ) ??
            0.0;

        final double radius = double.tryParse(
              premise['premises_radius'].toString(),
            ) ??
            50.0;

        final double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        print("PREMISE => ${premise['premises_name']}");
        print("DISTANCE => $distance");

        if (distance <= radius) {
          return premise;
        }
      }

      return null;
    } catch (e) {
      print("LOCATION ERROR => $e");

      return null;
    }
  }

  // =====================================================
  // VALIDATE USER INSIDE PREMISE
  // =====================================================

  static Future<bool> validateUserInPremise(
    List<dynamic> premises,
  ) async {
    final matched = await getMatchedPremise(premises);

    return matched != null;
  }
}
