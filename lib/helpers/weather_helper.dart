import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class WeatherData {
  final String city;
  final double temperature;
  final String description;
  final String icon;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.description,
    required this.icon,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      city: json['name'] ?? 'Unknown',
      temperature: (json['main']['temp'] ?? 0).toDouble(),
      description: json['weather'][0]['main'] ?? 'Clear',
      icon: json['weather'][0]['icon'] ?? '01d',
    );
  }
}

class ForecastData {
  final String city;
  final List<DailyForecast> dailyForecasts;

  ForecastData({required this.city, required this.dailyForecasts});
}

class DailyForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final String description;
  final String icon;
  final double humidity;
  final double windSpeed;

  DailyForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.description,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
  });
}

class WeatherHelper {
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static String get _apiKey => dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  static WeatherData _getDummyWeather() {
    return WeatherData(
      city: 'Yogyakarta',
      temperature: 28,
      description: 'Cerah',
      icon: '01d',
    );
  }

  static Future<WeatherData> getWeatherByCity(String city) async {
    try {
      if (_apiKey.isEmpty) {
        print('⚠️ OPENWEATHER_API_KEY not found in .env');
        return _getDummyWeather();
      }

      final url = Uri.parse(
        '$_baseUrl?q=$city&units=metric&lang=id&appid=$_apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherData.fromJson(json);
      } else if (response.statusCode == 404) {
        print('❌ City not found: $city');
        return _getDummyWeather();
      } else {
        throw Exception('Failed to load weather: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Weather Error: $e');
      return _getDummyWeather();
    }
  }

  static Future<WeatherData> getWeatherByCoords(
    double latitude,
    double longitude,
  ) async {
    try {
      if (_apiKey.isEmpty) {
        print('⚠️ OPENWEATHER_API_KEY not found in .env');
        return _getDummyWeather();
      }

      final url = Uri.parse(
        '$_baseUrl?lat=$latitude&lon=$longitude&units=metric&lang=id&appid=$_apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherData.fromJson(json);
      } else {
        throw Exception('Failed to load weather: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Weather Error: $e');
      return _getDummyWeather();
    }
  }

  static Future<ForecastData> getWeatherForecastByCity(String city) async {
    try {
      if (_apiKey.isEmpty) {
        print('⚠️ OPENWEATHER_API_KEY not found in .env');
        return _getDummyForecast(city);
      }

      final forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?q=$city&units=metric&lang=id&appid=$_apiKey';
      final url = Uri.parse(forecastUrl);

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final forecasts = json['list'] as List;

        Map<String, Map<String, dynamic>> groupedByDate = {};
        for (var item in forecasts) {
          final dt = DateTime.fromMillisecondsSinceEpoch((item['dt'] as int) * 1000);
          final dateKey = '${dt.year}-${dt.month}-${dt.day}';

          if (groupedByDate[dateKey] == null ||
              (item['dt_txt'] as String).contains('12:00')) {
            groupedByDate[dateKey] = item as Map<String, dynamic>;
          }
        }

        List<DailyForecast> dailyForecasts = [];
        for (var entry in groupedByDate.entries) {
          final item = entry.value;
          final dt = DateTime.fromMillisecondsSinceEpoch((item['dt'] as int) * 1000);
          
          final main = item['main'] as Map<String, dynamic>;
          final weather = (item['weather'] as List).cast<Map<String, dynamic>>();
          final wind = item['wind'] as Map<String, dynamic>;

          dailyForecasts.add(
            DailyForecast(
              date: dt,
              tempMin: (main['temp_min'] ?? 0).toDouble(),
              tempMax: (main['temp_max'] ?? 0).toDouble(),
              description: weather[0]['main'] ?? 'Clear',
              icon: weather[0]['icon'] ?? '01d',
              humidity: (main['humidity'] ?? 0).toDouble(),
              windSpeed: (wind['speed'] ?? 0).toDouble(),
            ),
          );
        }

        dailyForecasts.sort((a, b) => a.date.compareTo(b.date));

        return ForecastData(
          city: (json['city'] as Map<String, dynamic>)['name'] ?? 'Unknown',
          dailyForecasts: dailyForecasts.take(5).toList(),
        );
      } else if (response.statusCode == 404) {
        print('❌ City not found: $city');
        return _getDummyForecast(city);
      } else {
        throw Exception('Failed to load forecast: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Forecast Error: $e');
      return _getDummyForecast(city);
    }
  }

  static ForecastData _getDummyForecast(String city) {
    final now = DateTime.now();
    return ForecastData(
      city: city,
      dailyForecasts: List.generate(5, (i) {
        return DailyForecast(
          date: now.add(Duration(days: i)),
          tempMin: 25 + i.toDouble(),
          tempMax: 32 + i.toDouble(),
          description: 'Cerah',
          icon: '01d',
          humidity: 65.0,
          windSpeed: 10.0,
        );
      }),
    );
  }

  static String getWeatherEmoji(String iconCode) {
    if (iconCode.isEmpty) return '🌤️';

    final firstChar = iconCode[0];
    switch (firstChar) {
      case '0':
        return '☀️';
      case '1':
        return '☁️';
      case '2':
        return '⛈️';
      case '3':
        return '🌧️';
      case '4':
        return '🌧️';
      case '5':
        return '❄️';
      case '6':
        return '❄️';
      case '7':
        return '🌫️';
      case '8':
        return '☁️';
      default:
        return '🌤️';
    }
  }
}