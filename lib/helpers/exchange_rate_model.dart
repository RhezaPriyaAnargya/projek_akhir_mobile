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
