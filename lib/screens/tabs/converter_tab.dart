import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flag/flag.dart'; // <-- tambahkan package flag
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

  // -- Mata Uang --
  ExchangeRates? _rates;
  String _sourceCurrency = 'IDR';
  String? _targetCurrency;
  bool _loadingRates = true;
  bool _error = false;
  double _amount = 0;

  List<String> _availableCurrencies = [];

  // Mapping mata uang ke kode negara (ISO 3166‑1 alpha‑2) untuk Flag widget
  static const _currencyCountryMap = {
    // Afrika
    'AOA': 'AO', 'BIF': 'BI', 'BWP': 'BW', 'CDF': 'CD', 'CVE': 'CV',
    'DJF': 'DJ', 'DZD': 'DZ', 'EGP': 'EG', 'ERN': 'ER', 'ETB': 'ET',
    'GHS': 'GH', 'GMD': 'GM', 'GNF': 'GN', 'KES': 'KE', 'KMF': 'KM',
    'LRD': 'LR', 'LSL': 'LS', 'LYD': 'LY', 'MAD': 'MA', 'MGA': 'MG',
    'MRU': 'MR', 'MUR': 'MU', 'MWK': 'MW', 'MZN': 'MZ', 'NAD': 'NA',
    'NGN': 'NG', 'RWF': 'RW', 'SCR': 'SC', 'SDG': 'SD', 'SLE': 'SL',
    'SLL': 'SL', 'SOS': 'SO', 'SSP': 'SS', 'STN': 'ST', 'SZL': 'SZ',
    'TND': 'TN', 'TZS': 'TZ', 'UGX': 'UG', 'XAF': 'CM', 'XOF': 'SN',
    'ZAR': 'ZA', 'ZMW': 'ZM', 'ZWL': 'ZW', 'ZWG': 'ZW',

    // Amerika Utara
    'ANG': 'CW', // Netherlands Antilles -> Curaçao
    'XCG': 'CW', // Caribbean Guilder -> Curaçao
    'BBD': 'BB', 'BMD': 'BM', 'BSD': 'BS', 'BZD': 'BZ', 'CAD': 'CA',
    'CRC': 'CR', 'CUP': 'CU', 'DOP': 'DO', 'GTQ': 'GT', 'HNL': 'HN',
    'HTG': 'HT', 'JMD': 'JM', 'KYD': 'KY', 'MXN': 'MX', 'NIO': 'NI',
    'PAB': 'PA', 'TTD': 'TT', 'USD': 'US',

    // Amerika Selatan
    'ARS': 'AR', 'BOB': 'BO', 'BRL': 'BR', 'CLP': 'CL', 'CLF': 'CL',
    'COP': 'CO', 'GYD': 'GY', 'PEN': 'PE', 'PYG': 'PY', 'SRD': 'SR',
    'UYU': 'UY', 'VES': 'VE',

    // Asia
    'AED': 'AE', 'AFN': 'AF', 'AMD': 'AM', 'AZN': 'AZ', 'BDT': 'BD',
    'BHD': 'BH', 'BND': 'BN', 'BTN': 'BT', 'CNY': 'CN', 'CNH': 'CN',
    'GEL': 'GE', 'HKD': 'HK', 'IDR': 'ID', 'ILS': 'IL', 'INR': 'IN',
    'IQD': 'IQ', 'IRR': 'IR', 'JOD': 'JO', 'JPY': 'JP', 'KGS': 'KG',
    'KHR': 'KH', 'KRW': 'KR', 'KWD': 'KW', 'KZT': 'KZ', 'LAK': 'LA',
    'LBP': 'LB', 'LKR': 'LK', 'MMK': 'MM', 'MNT': 'MN', 'MOP': 'MO',
    'MVR': 'MV', 'MYR': 'MY', 'NPR': 'NP', 'OMR': 'OM', 'PHP': 'PH',
    'PKR': 'PK', 'QAR': 'QA', 'SAR': 'SA', 'SGD': 'SG', 'SYP': 'SY',
    'THB': 'TH', 'TJS': 'TJ', 'TMT': 'TM', 'TRY': 'TR', 'TWD': 'TW',
    'UZS': 'UZ', 'VND': 'VN', 'YER': 'YE',

    // Eropa
    'ALL': 'AL', 'BAM': 'BA', 'BGN': 'BG', 'BYN': 'BY', 'CHF': 'CH',
    'CZK': 'CZ', 'DKK': 'DK', 'EUR': 'EU', 'FOK': 'FO', // Faroe Islands
    'GBP': 'GB', 'HRK': 'HR', 'HUF': 'HU', 'ISK': 'IS', 'MDL': 'MD',
    'MKD': 'MK', 'NOK': 'NO', 'PLN': 'PL', 'RON': 'RO', 'RSD': 'RS',
    'RUB': 'RU', 'SEK': 'SE', 'UAH': 'UA',

    // Oseania
    'AUD': 'AU', 'FJD': 'FJ', 'NZD': 'NZ', 'PGK': 'PG', 'SBD': 'SB',
    'TOP': 'TO', 'TVD': 'TV', // Tuvalu
    'VUV': 'VU', 'WST': 'WS',

    // Special - tidak punya bendera default
    'XDR': 'un', // IMF Special Drawing Rights
  };
  // Widget bendera dari package flag (fallback ke bendera PBB jika tidak ditemukan)
  Widget _flagWidget(
    String currencyCode, {
    double width = 28,
    double height = 20,
  }) {
    final country = _currencyCountryMap[currencyCode] ?? 'un';
    return Flag.fromString(
      country,
      width: width,
      height: height,
      fit: BoxFit.fill,
    );
  }

  // -- Zona Waktu --
  List<String> _selectedTimezones = ['UTC'];
  List<String> _allTimezones = [];
  late Timer _timer;
  late DateTime _utc;

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
    _loadRates(_sourceCurrency);

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

  Future<void> _loadRates(String base) async {
    setState(() {
      _loadingRates = true;
      _error = false;
    });
    try {
      final rates = await ExchangeRateService.getRates(base: base);
      setState(() {
        _rates = rates;
        _availableCurrencies = rates.rates.keys.toList()..sort();
        _loadingRates = false;
      });
    } catch (_) {
      setState(() {
        _error = true;
        _loadingRates = false;
      });
    }
  }

  void _onSourceChanged(String? code) {
    if (code == null || code == _sourceCurrency) return;
    setState(() {
      _sourceCurrency = code;
      _targetCurrency = null;
      _amount = 0;
    });
    _ctrl.clear();
    _loadRates(code);
  }

  String _fmt(double v, String code) {
    if (v == 0) return '0';
    const noDecimal = {
      'JPY',
      'KRW',
      'IDR',
      'VND',
      'CLP',
      'PYG',
      'UGX',
      'GNF',
      'RWF',
      'BIF',
    };
    final decimals = noDecimal.contains(code) ? 0 : 2;
    return v.toStringAsFixed(decimals);
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

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

  // =================== UI ===================

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

        if (_loadingRates && _availableCurrencies.isEmpty)
          _loadingCard('Mengambil kurs terkini...')
        else if (_error && _rates == null)
          _errorCard()
        else ...[
          _currencyDropdown(
            label: 'Mata Uang Sumber',
            selected: _sourceCurrency,
            items: _availableCurrencies,
            onChanged: _onSourceChanged,
          ),
          const SizedBox(height: 12),
          _inputCard(),
          const SizedBox(height: 12),

          if (_loadingRates) _loadingCard('Mengambil kurs terkini...'),
          if (_error) _errorCard(),

          if (!_loadingRates && _rates != null)
            _currencyDropdown(
              label: 'Mata Uang Tujuan',
              selected: _targetCurrency,
              items: _availableCurrencies
                  .where((c) => c != _sourceCurrency)
                  .toList(),
              onChanged: (val) => setState(() => _targetCurrency = val),
            ),

          if (_targetCurrency != null && _amount > 0 && _rates != null) ...[
            const SizedBox(height: 16),
            _resultCard(_targetCurrency!),
          ],

          if (_rates != null) ...[const SizedBox(height: 10), _rateInfo()],
        ],

        const SizedBox(height: 24),

        // -- Zona Waktu --
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
            itemBuilder: (context, item, isSelected) => ListTile(
              title: Text(
                item.replaceAll('_', ' ').split('/').last,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(item, style: const TextStyle(fontSize: 11)),
            ),
          ),
          items: _allTimezones,
          onChanged: (zone) {
            if (zone != null && !_selectedTimezones.contains(zone)) {
              setState(() => _selectedTimezones.add(zone));
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
            .where((zone) => zone != 'UTC')
            .map(
              (zone) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _zoneCard(zone),
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

  Widget _currencyDropdown({
    required String label,
    required String? selected,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) => DropdownSearch<String>(
    popupProps: PopupProps.menu(
      showSearchBox: true,
      searchFieldProps: TextFieldProps(
        decoration: InputDecoration(
          hintText: 'Cari kode atau nama...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      itemBuilder: (context, code, isSelected) => ListTile(
        leading: SizedBox(
          width: 28,
          child: _flagWidget(code, width: 28, height: 20),
        ),
        title: Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
        selected: isSelected,
      ),
    ),
    items: items,
    itemAsString: (code) => code,
    filterFn: (code, filter) =>
        code.toLowerCase().contains(filter.toLowerCase()),
    onChanged: onChanged,
    selectedItem: selected,
    dropdownDecoratorProps: DropDownDecoratorProps(
      dropdownSearchDecoration: InputDecoration(
        labelText: label,
        prefixIcon: selected != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 28,
                  height: 20,
                  child: _flagWidget(selected, width: 28, height: 20),
                ),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 56,
          minHeight: 24,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _inputCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _flagWidget(_sourceCurrency, width: 28, height: 20),
            const SizedBox(width: 6),
            Text(
              _sourceCurrency,
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
              _sourceCurrency,
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
        _quickChips(),
      ],
    ),
  );

  Widget _quickChips() {
    final isIdr = _sourceCurrency == 'IDR';
    final amounts = isIdr
        ? [50000, 100000, 500000, 1000000]
        : [1, 10, 100, 1000];
    final labels = isIdr
        ? ['50rb', '100rb', '500rb', '1jt']
        : ['1', '10', '100', '1K'];

    return Wrap(
      spacing: 6,
      children: List.generate(amounts.length, (i) {
        return GestureDetector(
          onTap: () {
            _ctrl.text = amounts[i].toString();
            setState(() => _amount = amounts[i].toDouble());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              labels[i],
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _resultCard(String code) {
    final rate = _rates!.getRate(code) ?? 0;
    final result = _amount * rate;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
              _flagWidget(_sourceCurrency, width: 42, height: 30),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
              _flagWidget(code, width: 42, height: 30),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_fmt(_amount, _sourceCurrency)} $_sourceCurrency =',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(result, code)} $code',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1 $_sourceCurrency = ${rate.toStringAsFixed(6)} $code',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _rateInfo() => Row(
    children: [
      const Icon(Icons.check_circle, color: AppColors.success, size: 13),
      const SizedBox(width: 4),
      Text(
        'Update: ${_rates!.updatedAt.hour.toString().padLeft(2, '0')}:'
        '${_rates!.updatedAt.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(color: AppColors.success, fontSize: 11),
      ),
      const Spacer(),
      GestureDetector(
        onTap: () {
          ExchangeRateService.clearCache();
          _loadRates(_sourceCurrency);
        },
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
            'Gagal memuat kurs. Periksa koneksi Anda.',
            style: TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () => _loadRates(_sourceCurrency),
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
    final offset = tzNow.timeZoneOffset;
    final sign = offset.inHours >= 0 ? '+' : '';
    final hour = offset.inHours.abs().toString().padLeft(2, '0');
    final min = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final offsetStr = 'UTC$sign$hour:$min';
    final city = iana.split('/').last.replaceAll('_', ' ');
    String abbr = city;
    try {
      abbr = location.currentTimeZone.abbreviation;
    } catch (_) {}

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
                  _period(tzNow),
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
                '${tzNow.hour.toString().padLeft(2, '0')}:${tzNow.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ':${tzNow.second.toString().padLeft(2, '0')}',
                style: const TextStyle(
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
