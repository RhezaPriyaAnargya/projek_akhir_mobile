class ExchangeRates {
  final Map<String, double> rates;
  final String base;
  final DateTime updatedAt;

  ExchangeRates({
    required this.rates,
    required this.base,
    required this.updatedAt,
  });

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    final r = json['conversion_rates'] as Map<String, dynamic>;
    return ExchangeRates(
      base: json['base_code'] ?? 'IDR',
      rates: r.map((k, v) => MapEntry(k, (v as num).toDouble())),
      updatedAt: DateTime.now(),
    );
  }

  double? getRate(String code) => rates[code];
}
