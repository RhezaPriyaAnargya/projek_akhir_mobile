import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../helpers/app_colors.dart';
import '../../helpers/compass_painter.dart';

class TravelToolsTab extends StatefulWidget {
  const TravelToolsTab({super.key});

  @override
  State<TravelToolsTab> createState() => _TravelToolsTabState();
}

class _TravelToolsTabState extends State<TravelToolsTab> {
  // ── Pedometer ──
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  int _steps = 0;
  String _status = 'stopped';
  static const double _strideM = 0.762;
  static const double _calPerStep = 0.04;

  // ── Kompas + Kiblat ──
  StreamSubscription<MagnetometerEvent>? _magSub;
  double _heading = 0;
  double _qiblaAngle = 0;
  bool _locationLoaded = false;
  String _locationStatus = 'Mendeteksi lokasi...';
  int _initialSteps = 0;

  static const double _mekkahLat = 21.4225;
  static const double _mekkahLng = 39.8262;

  @override
  void initState() {
    super.initState();
    _initPedometer();
    _initCompass();
    _initLocation();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  void _initPedometer() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      setState(() => _status = 'permission denied');
      return;
    }
    _stepSub = Pedometer.stepCountStream.listen((e) {
      if (_initialSteps == 0) {
        _initialSteps = e.steps;
      }
      setState(() => _steps = e.steps - _initialSteps);
    });
    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (e) => setState(() => _status = e.status),
      onError: (_) {},
    );
  }

  void _initCompass() {
    _magSub = magnetometerEventStream().listen((e) {
      double angle = math.atan2(e.x, e.y) * (180 / math.pi);
      angle = (360 - angle) % 360;
      setState(() => _heading = angle);
    });
  }

  Future<void> _initLocation() async {
    setState(() {
      _locationLoaded = false;
      _locationStatus = 'Mendeteksi lokasi...';
    });
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _locationStatus = 'Layanan lokasi tidak aktif');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _locationStatus = 'Izin lokasi ditolak');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final qibla = _calcQibla(pos.latitude, pos.longitude);
      setState(() {
        _qiblaAngle = qibla;
        _locationLoaded = true;
        _locationStatus =
            '${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°';
      });
    } catch (_) {
      setState(() => _locationStatus = 'Gagal mendapatkan lokasi');
    }
  }

  double _calcQibla(double lat, double lng) {
    final latR = lat * math.pi / 180;
    final lngR = lng * math.pi / 180;
    final mLatR = _mekkahLat * math.pi / 180;
    final mLngR = _mekkahLng * math.pi / 180;
    final dLng = mLngR - lngR;
    final y = math.sin(dLng) * math.cos(mLatR);
    final x =
        math.cos(latR) * math.sin(mLatR) -
        math.sin(latR) * math.cos(mLatR) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double get _distanceKm => (_steps * _strideM) / 1000;
  double get _calories => _steps * _calPerStep;
  double get _needleAngle => (_qiblaAngle - _heading) * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _secHeader(
          Icons.directions_walk,
          'Deteksi Langkah Kaki',
          AppColors.success,
        ),
        const SizedBox(height: 10),
        _pedometerCard(),
        const SizedBox(height: 24),
        _secHeader(Icons.explore, 'Kompas Arah Kiblat', AppColors.qiblaGold),
        const SizedBox(height: 10),
        _qiblaCard(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _secHeader(IconData icon, String title, Color color) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _pedometerCard() {
    final isWalking = _status == 'walking';
    return _card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isWalking ? AppColors.successLight : AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isWalking
                    ? AppColors.success.withOpacity(0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isWalking
                        ? AppColors.success
                        : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isWalking ? 'Sedang Berjalan' : 'Berhenti',
                  style: TextStyle(
                    color: isWalking
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$_steps',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Text(
            'langkah',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  Icons.straighten,
                  '${_distanceKm.toStringAsFixed(2)} km',
                  'Jarak',
                  AppColors.primary,
                  AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statChip(
                  Icons.local_fire_department,
                  '${_calories.toStringAsFixed(1)} kkal',
                  'Kalori',
                  AppColors.danger,
                  AppColors.dangerLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _initialSteps = _initialSteps + _steps;
                setState(() => _steps = 0);
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Langkah'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    IconData icon,
    String value,
    String label,
    Color color,
    Color bg,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _qiblaCard() => _card(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _locationLoaded ? Icons.location_on : Icons.location_searching,
              color: _locationLoaded
                  ? AppColors.success
                  : AppColors.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              _locationStatus,
              style: TextStyle(
                color: _locationLoaded
                    ? AppColors.success
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!_locationLoaded)
          Column(
            children: [
              const SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.qiblaGold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _locationStatus,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: CompassPainter(
                    heading: _heading,
                    needleAngle: _needleAngle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.qiblaGoldLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.qiblaGold.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🕋', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'Kiblat: ${_qiblaAngle.toStringAsFixed(1)}°',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kompas: ${_heading.toStringAsFixed(1)}°',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Putar ponsel hingga jarum emas mengarah lurus ke atas',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _initLocation,
          icon: const Icon(Icons.my_location, size: 14),
          label: const Text('Perbarui Lokasi', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}
