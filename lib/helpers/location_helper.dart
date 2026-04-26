import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationHelper {
  /// Get current user location
  static Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openLocationSettings();
        return null;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      // Coba last known position dulu (instan)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        print(
          '>>> pakai lastKnown: ${lastKnown.latitude}, ${lastKnown.longitude}',
        );
        return lastKnown;
      }

      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('GPS timeout'),
          );

      print(
        '>>> pakai getCurrentPosition: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Convert Position to LatLng for flutter_map
  static LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }

  /// Default location (Yogyakarta) for fallback
  static const LatLng defaultLocation = LatLng(-7.797068, 110.370529);

  /// Get location from LatLng (for display in AddPlanScreen)
  static String formatLocation(LatLng location) {
    return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
  }
}
