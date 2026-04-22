import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../helpers/app_colors.dart';
import '../../helpers/exchange_rate_model.dart';
import '../../helpers/exchange_rate_service.dart';

class ConverterTab extends StatefulWidget {
  const ConverterTab({super.key});

  @override
  State<ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<ConverterTab> {
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
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
