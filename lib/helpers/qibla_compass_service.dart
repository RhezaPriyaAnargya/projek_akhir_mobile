import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class QiblaCompassService {
  static const double mekkahLat = 21.4225;
  static const double mekkahLng = 39.8262;

  StreamSubscription<MagnetometerEvent>? _magSub;
  double _heading = 0;
  double _qiblaAngle = 0;
  bool _locationLoaded = false;
  String _locationStatus = 'Mendeteksi lokasi...';
  Position? _currentPosition;

  // Callback untuk update UI
  Function(double heading, double qiblaAngle, bool loaded, String status)?
  onUpdate;

  void initCompass() {
    _magSub = magnetometerEventStream().listen((e) {
      double angle = math.atan2(e.x, e.y) * (180 / math.pi);
      angle = (360 - angle) % 360;
      _heading = angle;
      _notifyUpdate();
    });
  }

  Future<void> refreshLocation() async {
    _locationStatus = 'Mendeteksi lokasi...';
    _locationLoaded = false;
    _notifyUpdate();

    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _locationStatus = 'Layanan lokasi tidak aktif';
        _notifyUpdate();
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _locationStatus = 'Izin lokasi ditolak';
        _notifyUpdate();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _currentPosition = pos;
      _qiblaAngle = _calculateQibla(pos.latitude, pos.longitude);
      _locationLoaded = true;
      _locationStatus =
          '${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°';
      _notifyUpdate();
    } catch (_) {
      _locationStatus = 'Gagal mendapatkan lokasi';
      _notifyUpdate();
    }
  }

  double _calculateQibla(double lat, double lng) {
    final latR = lat * math.pi / 180;
    final lngR = lng * math.pi / 180;
    final mLatR = mekkahLat * math.pi / 180;
    final mLngR = mekkahLng * math.pi / 180;
    final dLng = mLngR - lngR;
    final y = math.sin(dLng) * math.cos(mLatR);
    final x =
        math.cos(latR) * math.sin(mLatR) -
        math.sin(latR) * math.cos(mLatR) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _notifyUpdate() {
    onUpdate?.call(_heading, _qiblaAngle, _locationLoaded, _locationStatus);
  }

  void dispose() {
    _magSub?.cancel();
  }

  double get heading => _heading;
  double get qiblaAngle => _qiblaAngle;
  bool get locationLoaded => _locationLoaded;
  String get locationStatus => _locationStatus;
  double get needleAngle => (_qiblaAngle - _heading) * math.pi / 180;
}
