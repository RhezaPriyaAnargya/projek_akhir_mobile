import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'exchange_rate_model.dart';

class ExchangeRateService {
  static String get _apiKey => dotenv.env['EXCHANGE_API_KEY'] ?? '';

  // Cache per base currency
  static final Map<String, ExchangeRates> _cache = {};
  static final Map<String, DateTime> _lastFetch = {};
  static const _cacheDuration = Duration(hours: 1);

  static Future<ExchangeRates> getRates({String base = 'IDR'}) async {
    final cached = _cache[base];
    final lastFetch = _lastFetch[base];
    if (cached != null &&
        lastFetch != null &&
        DateTime.now().difference(lastFetch) < _cacheDuration) {
      return cached;
    }

    try {
      final url = 'https://v6.exchangerate-api.com/v6/$_apiKey/latest/$base';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = ExchangeRates.fromJson(json.decode(res.body));
        _cache[base] = data;
        _lastFetch[base] = DateTime.now();
        return data;
      }
      throw Exception('Status ${res.statusCode}');
    } catch (_) {
      // Fallback: kembalikan cache lama jika ada, meski sudah expired
      if (_cache.containsKey(base)) return _cache[base]!;
      rethrow;
    }
  }

  static void clearCache() {
    _cache.clear();
    _lastFetch.clear();
  }
}
