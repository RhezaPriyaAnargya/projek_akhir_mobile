import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ─────────────────────────────────────────────
// THEME COLORS
// ─────────────────────────────────────────────

class AppColors {
  static const background = Color(0xFFF5F7FA);
  static const card = Colors.white;
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFEFF6FF);
  static const accent = Color(0xFF0EA5E9);
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFF0FDF4);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFFFBEB);
  static const danger = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFEF2F2);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const qiblaGold = Color(0xFFF59E0B);
  static const qiblaGoldLight = Color(0xFFFFFBEB);
}

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────

class ExchangeRates {
  final double usd, eur, jpy, sgd;
  final DateTime updatedAt;

  ExchangeRates({
    required this.usd,
    required this.eur,
    required this.jpy,
    required this.sgd,
    required this.updatedAt,
  });

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    final r = json['conversion_rates'] as Map<String, dynamic>;
    return ExchangeRates(
      usd: (r['USD'] as num).toDouble(),
      eur: (r['EUR'] as num).toDouble(),
      jpy: (r['JPY'] as num).toDouble(),
      sgd: (r['SGD'] as num).toDouble(),
      updatedAt: DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────
// SERVICE — Exchange Rate
// ─────────────────────────────────────────────

class ExchangeRateService {
  static String get _apiKey => dotenv.env['EXCHANGE_API_KEY'] ?? '';
  static String get _baseUrl =>
      'https://v6.exchangerate-api.com/v6/$_apiKey/latest/IDR';

  static ExchangeRates? _cache;
  static DateTime? _lastFetch;

  static Future<ExchangeRates> getRates() async {
    if (_cache != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(hours: 1)) {
      return _cache!;
    }
    try {
      final res = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        _cache = ExchangeRates.fromJson(json.decode(res.body));
        _lastFetch = DateTime.now();
        return _cache!;
      }
      throw Exception('Status ${res.statusCode}');
    } catch (_) {
      return ExchangeRates(
        usd: 0.000062,
        eur: 0.000057,
        jpy: 0.0093,
        sgd: 0.000083,
        updatedAt: DateTime.now(),
      );
    }
  }
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────

class TravelUtilitiesScreen extends StatefulWidget {
  const TravelUtilitiesScreen({super.key});

  @override
  State<TravelUtilitiesScreen> createState() => _TravelUtilitiesScreenState();
}

class _TravelUtilitiesScreenState extends State<TravelUtilitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.travel_explore, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Travel Utilities',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primary,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.currency_exchange, size: 15),
                      SizedBox(width: 6),
                      Text('Konverter'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore, size: 15),
                      SizedBox(width: 6),
                      Text('Travel Tools'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ConverterTab(), _TravelToolsTab()],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 1 — KONVERTER (Mata Uang + Zona Waktu)
// ─────────────────────────────────────────────

class _ConverterTab extends StatefulWidget {
  const _ConverterTab();

  @override
  State<_ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<_ConverterTab> {
  final _ctrl = TextEditingController();
  ExchangeRates? _rates;
  bool _loading = true, _error = false;
  double _idr = 0;

  late Timer _timer;
  late DateTime _utc;

  static const _offsets = {'WIB': 7, 'WITA': 8, 'WIT': 9, 'London': 0};
  static const _zoneLabel = {
    'WIB': 'Waktu Indonesia Barat',
    'WITA': 'Waktu Indonesia Tengah',
    'WIT': 'Waktu Indonesia Timur',
    'London': 'Greenwich Mean Time',
  };
  static const _zoneFlag = {
    'WIB': '🌴',
    'WITA': '🏝️',
    'WIT': '🌊',
    'London': '🇬🇧',
  };
  static const _zoneColor = {
    'WIB': AppColors.success,
    'WITA': AppColors.primary,
    'WIT': AppColors.warning,
    'London': AppColors.danger,
  };

  @override
  void initState() {
    super.initState();
    _utc = DateTime.now().toUtc();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _utc = DateTime.now().toUtc()),
    );
    _loadRates();
    _ctrl.addListener(() {
      final t = _ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      setState(() => _idr = double.tryParse(t) ?? 0);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final r = await ExchangeRateService.getRates();
      setState(() {
        _rates = r;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  String _fmt(double v, int d) =>
      v == 0 ? '0' : (v >= 1 ? v.toStringAsFixed(d) : v.toStringAsFixed(4));

  DateTime _zt(String z) => _utc.add(Duration(hours: _offsets[z]!));

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) {
    const d = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d[dt.weekday - 1]}, ${dt.day} ${m[dt.month - 1]}';
  }

  String _period(DateTime dt) {
    if (dt.hour >= 5 && dt.hour < 12) return 'Pagi ☀️';
    if (dt.hour >= 12 && dt.hour < 15) return 'Siang 🌤️';
    if (dt.hour >= 15 && dt.hour < 18) return 'Sore 🌅';
    return 'Malam 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _secHeader(
          Icons.currency_exchange,
          'Konversi Mata Uang',
          AppColors.primary,
        ),
        const SizedBox(height: 10),
        _inputCard(),
        const SizedBox(height: 10),
        if (_loading) _loadingCard(),
        if (_error) _errorCard(),
        if (_rates != null && !_loading) ...[
          _rateUpdated(),
          const SizedBox(height: 8),
          _resultCard(
            '🇺🇸',
            'USD',
            'Dolar Amerika',
            _rates!.usd,
            _idr * _rates!.usd,
            AppColors.success,
            AppColors.successLight,
          ),
          const SizedBox(height: 8),
          _resultCard(
            '🇪🇺',
            'EUR',
            'Euro',
            _rates!.eur,
            _idr * _rates!.eur,
            AppColors.primary,
            AppColors.primaryLight,
          ),
          const SizedBox(height: 8),
          _resultCard(
            '🇯🇵',
            'JPY',
            'Yen Jepang',
            _rates!.jpy,
            _idr * _rates!.jpy,
            AppColors.danger,
            AppColors.dangerLight,
          ),
          const SizedBox(height: 8),
          _resultCard(
            '🇸🇬',
            'SGD',
            'Dolar Singapura',
            _rates!.sgd,
            _idr * _rates!.sgd,
            AppColors.warning,
            AppColors.warningLight,
          ),
        ],
        const SizedBox(height: 24),
        _secHeader(
          Icons.access_time_filled,
          'Zona Waktu Real-time',
          AppColors.accent,
        ),
        const SizedBox(height: 10),
        _utcCard(),
        const SizedBox(height: 8),
        ..._offsets.keys.map(
          (z) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _zoneCard(z),
          ),
        ),
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

  Widget _inputCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('🇮🇩', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text(
                  'Rupiah Indonesia (IDR)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Rp',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: AppColors.border,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_ctrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      setState(() => _idr = 0);
                    },
                    child: const Icon(
                      Icons.cancel,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [50000, 100000, 500000, 1000000].map((a) {
                return GestureDetector(
                  onTap: () {
                    _ctrl.text = a.toString();
                    setState(() => _idr = a.toDouble());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      a >= 1000000
                          ? '${(a / 1000000).toStringAsFixed(0)}jt'
                          : '${(a / 1000).toStringAsFixed(0)}rb',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  Widget _resultCard(
    String flag,
    String currency,
    String name,
    double rate,
    double result,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1 IDR = ${_fmt(rate, 6)} $currency',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _idr == 0 ? '--' : _fmt(result, currency == 'JPY' ? 0 : 2),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() => _card(
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Mengambil kurs terkini...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Gagal memuat kurs. Menampilkan estimasi.',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _loadRates,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _rateUpdated() => Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 13),
          const SizedBox(width: 4),
          Text(
            'Update: ${_rates!.updatedAt.hour.toString().padLeft(2, '0')}:${_rates!.updatedAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: AppColors.success, fontSize: 11),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadRates,
            child: const Text(
              'Refresh',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ],
      );

  Widget _utcCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Universal Time (UTC)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _fmtTime(_utc),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtDate(_utc),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _zoneCard(String zone) {
    final zt = _zt(zone);
    final color = _zoneColor[zone]!;
    final offset = _offsets[zone]!;
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _zoneFlag[zone]!,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      zone,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        offset >= 0 ? 'UTC+$offset' : 'UTC$offset',
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _zoneLabel[zone]!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _period(zt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtTime(zt).substring(0, 5),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ':${_fmtTime(zt).substring(6)}',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
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

// ─────────────────────────────────────────────
// TAB 2 — TRAVEL TOOLS (Pedometer + Kiblat)
// ─────────────────────────────────────────────

class _TravelToolsTab extends StatefulWidget {
  const _TravelToolsTab();

  @override
  State<_TravelToolsTab> createState() => _TravelToolsTabState();
}

class _TravelToolsTabState extends State<_TravelToolsTab> {
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

  void _initPedometer() {
    _stepSub = Pedometer.stepCountStream.listen(
      (e) => setState(() => _steps = e.steps),
      onError: (_) => setState(() => _status = 'error'),
    );
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
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => _locationStatus = 'Izin lokasi ditolak');
      return;
    }

    // Coba lokasi terakhir dulu (instan, tidak perlu GPS)
    Position? pos = await Geolocator.getLastKnownPosition();

    if (pos == null) {
      // Paksa timeout manual pakai Future.any
      pos = await Future.any([
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ),
        Future.delayed(const Duration(seconds: 6)).then((_) => null),
      ]);
    }

    if (pos == null) {
      // Fallback koordinat Yogyakarta kalau tetap gagal
      setState(() {
        _qiblaAngle = _calcQibla(-7.7956, 110.3695);
        _locationLoaded = true;
        _locationStatus = 'Estimasi (Yogyakarta)';
      });
      return;
    }

    setState(() {
      _qiblaAngle = _calcQibla(pos!.latitude, pos.longitude);
      _locationLoaded = true;
      _locationStatus =
          '${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°';
    });
  } catch (e) {
    // Fallback koordinat Yogyakarta
    setState(() {
      _qiblaAngle = _calcQibla(-7.7956, 110.3695);
      _locationLoaded = true;
      _locationStatus = 'Estimasi (Yogyakarta)';
    });
  }
}

  double _calcQibla(double lat, double lng) {
    final latR = lat * math.pi / 180;
    final lngR = lng * math.pi / 180;
    final mLatR = _mekkahLat * math.pi / 180;
    final mLngR = _mekkahLng * math.pi / 180;
    final dLng = mLngR - lngR;
    final y = math.sin(dLng) * math.cos(mLatR);
    final x = math.cos(latR) * math.sin(mLatR) -
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

  // ── Pedometer Card ──
  Widget _pedometerCard() {
    final isWalking = _status == 'walking';
    return _card(
      child: Column(
        children: [
          // Status badge
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
                    color:
                        isWalking ? AppColors.success : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isWalking ? 'Sedang Berjalan' : 'Berhenti',
                  style: TextStyle(
                    color:
                        isWalking ? AppColors.success : AppColors.textSecondary,
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
              onPressed: () => setState(() => _steps = 0),
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
  ) =>
      Container(
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

  // ── Qibla Card ──
  Widget _qiblaCard() => _card(
        child: Column(
          children: [
            // Lokasi info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _locationLoaded
                      ? Icons.location_on
                      : Icons.location_searching,
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
                      child:
                          CircularProgressIndicator(color: AppColors.qiblaGold),
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
                      painter: _CompassPainter(
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
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initLocation,
              icon: const Icon(Icons.my_location, size: 14),
              label:
                  const Text('Perbarui Lokasi', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

// ─────────────────────────────────────────────
// CUSTOM PAINTER — Kompas Kiblat
// ─────────────────────────────────────────────

class _CompassPainter extends CustomPainter {
  final double heading;
  final double needleAngle;

  const _CompassPainter({required this.heading, required this.needleAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Background
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = AppColors.background);

    // Border luar
    canvas.drawCircle(
      Offset(cx, cy),
      r - 1,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Tick marks
    for (int i = 0; i < 72; i++) {
      final angle = (i * 5 - heading) * math.pi / 180;
      final isMain = i % 18 == 0;
      final isMid = i % 9 == 0;
      final inner = isMain ? r - 28 : (isMid ? r - 20 : r - 14);
      canvas.drawLine(
        Offset(cx + inner * math.sin(angle), cy - inner * math.cos(angle)),
        Offset(cx + (r - 8) * math.sin(angle), cy - (r - 8) * math.cos(angle)),
        Paint()
          ..color = isMain ? AppColors.textSecondary : AppColors.border
          ..strokeWidth = isMain ? 2 : 1,
      );
    }

    // Label arah (U/T/S/B) — dirotasi sesuai heading
    final dirs = ['U', 'T', 'S', 'B'];
    final dirDeg = [0.0, 90.0, 180.0, 270.0];
    for (int i = 0; i < dirs.length; i++) {
      final angle = (dirDeg[i] - heading) * math.pi / 180;
      final dx = cx + (r - 22) * math.sin(angle);
      final dy = cy - (r - 22) * math.cos(angle);
      final tp = TextPainter(
        text: TextSpan(
          text: dirs[i],
          style: TextStyle(
            color: i == 0 ? AppColors.danger : AppColors.textSecondary,
            fontSize: i == 0 ? 14 : 11,
            fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }

    // Lingkaran dalam (putih)
    canvas.drawCircle(Offset(cx, cy), r * 0.55, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.55,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Jarum Kiblat ──
    _drawNeedle(canvas, cx, cy, r);

    // Titik tengah
    canvas.drawCircle(Offset(cx, cy), 9, Paint()..color = AppColors.qiblaGold);
    canvas.drawCircle(
      Offset(cx, cy),
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawNeedle(Canvas canvas, double cx, double cy, double r) {
    final needleLen = r * 0.46;
    final halfW = 9.0;
    final perp = needleAngle + math.pi / 2;

    final tipX = cx + needleLen * math.sin(needleAngle);
    final tipY = cy - needleLen * math.cos(needleAngle);
    final tailX = cx - needleLen * 0.32 * math.sin(needleAngle);
    final tailY = cy + needleLen * 0.32 * math.cos(needleAngle);
    final lx = cx + halfW * math.sin(perp);
    final ly = cy - halfW * math.cos(perp);
    final rx = cx - halfW * math.sin(perp);
    final ry = cy + halfW * math.cos(perp);

    // Segitiga emas (arah kiblat)
    canvas.drawPath(
      Path()
        ..moveTo(tipX, tipY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      Paint()..color = AppColors.qiblaGold,
    );

    // Segitiga abu (ekor)
    canvas.drawPath(
      Path()
        ..moveTo(tailX, tailY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      Paint()..color = const Color(0xFFCBD5E1),
    );

    // Outline putih tipis
    final outline = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(
      Path()
        ..moveTo(tipX, tipY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      outline,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tailX, tailY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      outline,
    );

    // Emoji Ka'bah di ujung jarum
    final tp = TextPainter(
      text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(tipX - tp.width / 2, tipY - tp.height / 2 - 4));
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.heading != heading || old.needleAngle != needleAngle;
}
