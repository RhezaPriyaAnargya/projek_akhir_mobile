import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../helpers/app_colors.dart';

/// Service untuk mata uang (Frankfurter API)
class CurrencyService {
  static const _baseUrl = 'https://api.frankfurter.app';

  static Future<Map<String, String>> getCurrencies() async {
    final res = await http.get(Uri.parse('$_baseUrl/currencies'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return Map<String, String>.from(data);
    } else {
      throw Exception('Failed to load currencies');
    }
  }

  static Future<Map<String, double>> getRates(String base) async {
    final res = await http.get(Uri.parse('$_baseUrl/latest?from=$base'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return Map<String, double>.from(data['rates']);
    } else {
      throw Exception('Failed to load rates');
    }
  }
}

class ConverterTab extends StatefulWidget {
  const ConverterTab({super.key});

  @override
  State<ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<ConverterTab> {
  final _ctrl = TextEditingController();

  // -- Mata Uang --
  List<MapEntry<String, String>> _currencies = [];
  String? _sourceCurrency;
  String? _targetCurrency; // mata uang tujuan (hanya satu)
  Map<String, double> _rates = {};
  bool _loadingCurrencies = true;
  bool _loadingRates = false;
  bool _error = false;
  double _amount = 0;

  // -- Zona Waktu --
  List<String> _selectedTimezones = ['UTC'];
  List<String> _allTimezones = [];

  late Timer _timer;
  late DateTime _utc;

  // Mapping bendera
  static const Map<String, String> _currencyFlag = {
    'USD': '🇺🇸',
    'EUR': '🇵🇹',
    'JPY': '🇯🇵',
    'GBP': '🇬🇧',
    'AUD': '🇦🇺',
    'CAD': '🇨🇦',
    'CHF': '🇨🇮',
    'CNY': '🇨🇳',
    'SGD': '🇸🇬',
    'MYR': '🇲🇾',
    'SAR': '🇸🇦',
    'AED': '🇦🇪',
    'KRW': '🇰🇷',
    'INR': '🇮🇳',
    'IDR': '🇮🇩',
    'THB': '🇹🇭',
    'PHP': '🇵🇭',
    'VND': '🇻🇳',
    'BRL': '🇧🇷',
    'MXN': '🇲🇽',
    'ZAR': '🇿🇦',
    'RUB': '🇷🇺',
    'TRY': '🇹🇷',
    'NGN': '🇳🇬',
    'EGP': '🇪🇬',
    'HKD': '🇭🇰',
    'NZD': '🇳🇿',
    'SEK': '🇸🇪',
    'NOK': '🇳🇴',
    'DKK': '🇩🇰',
    'PLN': '🇵🇱',
    'CZK': '🇨🇿',
    'HUF': '🇭🇺',
    'RON': '🇷🇴',
    'BGN': '🇧🇬',
    'HRK': '🇭🇷',
  };

  @override
  void initState() {
    super.initState();
    _utc = DateTime.now().toUtc();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _utc = DateTime.now().toUtc()),
    );
    tz_data.initializeTimeZones();
    _allTimezones = tz.timeZoneDatabase.locations.keys.toList()..sort();
    _loadCurrencies();

    _ctrl.addListener(() {
      final t = _ctrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
      setState(() => _amount = double.tryParse(t) ?? 0);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencies() async {
    setState(() {
      _loadingCurrencies = true;
      _error = false;
    });
    try {
      final map = await CurrencyService.getCurrencies();
      _currencies = map.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      if (_currencies.any((e) => e.key == 'IDR')) {
        _sourceCurrency = 'IDR';
        _loadRates('IDR');
      }
      setState(() => _loadingCurrencies = false);
    } catch (_) {
      setState(() {
        _error = true;
        _loadingCurrencies = false;
      });
    }
  }

  Future<void> _loadRates(String base) async {
    setState(() {
      _loadingRates = true;
      _error = false;
    });
    try {
      final rates = await CurrencyService.getRates(base);
      setState(() {
        _rates = rates;
        _loadingRates = false;
      });
    } catch (_) {
      setState(() {
        _error = true;
        _loadingRates = false;
      });
    }
  }

  void _onSourceChanged(String? newCurrency) {
    if (newCurrency == null || newCurrency == _sourceCurrency) return;
    setState(() {
      _sourceCurrency = newCurrency;
      _targetCurrency = null; // reset target saat sumber berubah
      _amount = 0;
    });
    _ctrl.clear();
    _loadRates(newCurrency);
  }

  void _onTargetChanged(String? newTarget) {
    if (newTarget == null) return;
    setState(() => _targetCurrency = newTarget);
  }

  String _getFlag(String code) => _currencyFlag[code] ?? '🏳️';
  String _fmt(double v, int d) => v == 0
      ? '0'
      : (v >= 1 ? v.toStringAsFixed(d) : v.toStringAsFixed(d > 4 ? d : 4));

  DateTime _localTime(String iana) {
    final loc = tz.getLocation(iana);
    return tz.TZDateTime.from(_utc, loc);
  }

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

  // ================= UI ===================
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
        const SizedBox(height: 12),

        if (_loadingCurrencies)
          _loadingCard('Memuat daftar mata uang...')
        else if (_error && _currencies.isEmpty)
          _errorCard()
        else ...[
          // Dropdown SUMBER
          DropdownSearch<String>(
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Cari mata uang...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            items: _currencies.map((e) => '${e.key} - ${e.value}').toList(),
            onChanged: (value) {
              final code = value?.split(' - ').first;
              _onSourceChanged(code);
            },
            selectedItem: _sourceCurrency != null
                ? '$_sourceCurrency - ${_currencies.firstWhere((e) => e.key == _sourceCurrency).value}'
                : null,
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Mata Uang Sumber',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Input nominal (muncul setelah sumber dipilih)
          if (_sourceCurrency != null) _inputCard(),
          if (_loadingRates) _loadingCard('Mengambil kurs terkini...'),
          if (_error && _sourceCurrency != null) _errorCard(),

          // Dropdown TUJUAN (hanya jika rates sudah siap dan bukan loading)
          if (!_loadingRates &&
              _rates.isNotEmpty &&
              _sourceCurrency != null) ...[
            const SizedBox(height: 12),
            DropdownSearch<String>(
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: 'Cari mata uang tujuan...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              // Tampilkan semua kode dari _rates kecuali sumber
              items: _rates.keys.where((k) => k != _sourceCurrency).toList()
                ..sort(),
              itemAsString: (code) =>
                  '$code - ${_currencies.firstWhere((e) => e.key == code, orElse: () => MapEntry(code, code)).value}',
              onChanged: _onTargetChanged,
              selectedItem: _targetCurrency,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Mata Uang Tujuan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          // Hasil konversi (hanya jika target sudah dipilih)
          if (_targetCurrency != null &&
              _amount > 0 &&
              _rates.containsKey(_targetCurrency)) ...[
            const SizedBox(height: 16),
            _resultCard(
              _targetCurrency!,
              _currencies
                  .firstWhere(
                    (e) => e.key == _targetCurrency,
                    orElse: () => MapEntry(_targetCurrency!, _targetCurrency!),
                  )
                  .value,
              _rates[_targetCurrency]!,
            ),
          ],
        ],

        const SizedBox(height: 24),

        // -- Zona waktu (tidak berubah) --
        _secHeader(
          Icons.access_time_filled,
          'Zona Waktu Real-time',
          AppColors.accent,
        ),
        const SizedBox(height: 12),
        DropdownSearch<String>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Cari kota atau zona...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            itemBuilder: (context, item, isSelected) {
              return ListTile(
                title: Text(
                  item.replaceAll('_', ' ').split('/').last,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(item, style: const TextStyle(fontSize: 11)),
              );
            },
          ),
          items: _allTimezones,
          onChanged: (tz) {
            if (tz != null && !_selectedTimezones.contains(tz)) {
              setState(() => _selectedTimezones.add(tz));
            }
          },
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: 'Tambah Zona Waktu',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          clearButtonProps: const ClearButtonProps(isVisible: true),
        ),
        const SizedBox(height: 12),
        _utcCard(),
        const SizedBox(height: 8),
        ..._selectedTimezones
            .where((tz) => tz != 'UTC')
            .map(
              (tz) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _zoneCard(tz),
              ),
            ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ========= WIDGET PEMBANTU =========
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

  Widget _inputCard() {
    final sourceName = _currencies
        .firstWhere(
          (e) => e.key == _sourceCurrency,
          orElse: () => MapEntry(_sourceCurrency!, _sourceCurrency!),
        )
        .value;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getFlag(_sourceCurrency!),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
              Text(
                '$sourceName (${_sourceCurrency!})',
                style: const TextStyle(
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
              Text(
                _sourceCurrency!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
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
                    setState(() => _amount = 0);
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
                  setState(() => _amount = a.toDouble());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
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
  }

  Widget _resultCard(String currencyCode, String currencyName, double rate) {
    final result = _amount * rate;
    final flag = _getFlag(currencyCode);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getFlag(_sourceCurrency!),
                style: const TextStyle(fontSize: 28),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
              Text(flag, style: const TextStyle(fontSize: 28)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_fmt(_amount, 2)} $_sourceCurrency =',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(result, currencyCode == 'JPY' ? 0 : 2)} $currencyCode',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1 $_sourceCurrency = ${_fmt(rate, 6)} $currencyCode',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard([String msg = 'Memuat...']) => _card(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          msg,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
            'Gagal memuat data. Periksa koneksi Anda.',
            style: TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () {
            if (_sourceCurrency != null) {
              _loadRates(_sourceCurrency!);
            } else {
              _loadCurrencies();
            }
          },
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
        'Update: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        style: const TextStyle(color: AppColors.success, fontSize: 11),
      ),
      const Spacer(),
      GestureDetector(
        onTap: () => _loadRates(_sourceCurrency!),
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

  Widget _zoneCard(String iana) {
    final location = tz.getLocation(iana);
    final tzNow = tz.TZDateTime.from(_utc, location);
    final local = tzNow;
    final offset = tzNow.timeZoneOffset;
    final sign = offset.inHours >= 0 ? '+' : '';
    final hour = offset.inHours.abs().toString().padLeft(2, '0');
    final min = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final offsetStr = 'UTC$sign$hour:$min';
    final city = iana.split('/').last.replaceAll('_', ' ');
    String abbr = '';
    try {
      abbr = location.currentTimeZone.abbreviation;
    } catch (_) {
      abbr = city;
    }
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.public, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$abbr ($offsetStr)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _period(local),
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
                '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ':${local.second.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _selectedTimezones.remove(iana)),
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
