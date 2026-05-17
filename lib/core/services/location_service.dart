import 'package:geolocator/geolocator.dart';

class LocationService {
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
      print("PERMISSION ERROR => $e");

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
        final double lat = double.tryParse(
              premise['premises_latitude']?.toString() ?? "0",
            ) ??
            0.0;

        final double lng = double.tryParse(
              premise['premises_longitude']?.toString() ?? "0",
            ) ??
            0.0;

        final double radius = double.tryParse(
              premise['premises_radius']?.toString() ?? "100",
            ) ??
            100.0;

        final double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        print("PREMISE => ${premise['premises_name']}");

        print("DISTANCE => $distance");

        print("RADIUS => $radius");

        if (distance <= radius) {
          return Map<String, dynamic>.from(
            premise,
          );
        }
      }

      return null;
    } catch (e) {
      print("MATCH PREMISE ERROR => $e");

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

      final double lat = double.tryParse(
            premise['premises_latitude']?.toString() ?? "0",
          ) ??
          0.0;

      final double lng = double.tryParse(
            premise['premises_longitude']?.toString() ?? "0",
          ) ??
          0.0;

      final double radius = double.tryParse(
            premise['premises_radius']?.toString() ?? "100",
          ) ??
          100.0;

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );

      print("========== PREMISE CHECK ==========");
      print("PREMISE => ${premise['premises_name']}");
      print("DISTANCE => $distance");
      print("RADIUS => $radius");
      print("===================================");

      return distance <= radius;
    } catch (e) {
      print("INSIDE PREMISE ERROR => $e");

      return false;
    }
  }
}
