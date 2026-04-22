import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'exchange_rate_model.dart';

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
