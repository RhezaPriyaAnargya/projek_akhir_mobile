import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class AIHelper {
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const int MAX_OUTPUT_LENGTH = 2000;

  static Future<String> generateTravelDetails(
    String title,
    String date,
    String location,
  ) async {
    try {
      final prompt = '''Buatkan panduan perjalanan singkat & praktis dalam BAHASA INDONESIA SAJA untuk:
Judul: $title | Tanggal: $date | Lokasi: $location

GUNAKAN FORMAT INI (RINGKAS & TEPAT 1500-2000 KARAKTER):

**⏰ Itinerary Singkat** (per hari, 1-2 baris)
- Hari 1: [3-4 aktivitas utama]
- Hari 2: [3-4 aktivitas utama]
(dst sesuai jumlah hari)

**🏨 Hotel Rekomendasi** (cukup 2 pilihan)
- [Nama Hotel] (budget/standard/mewah) - Rp [harga]
- [Nama Hotel] (budget/standard/mewah) - Rp [harga]

**🍽️ Kuliner** (3-4 item saja)
- [Makanan] - [lokasi] - [deskripsi singkat]

**💰 Budget Estimasi** (breakdown ringkas)
- Transportasi: Rp [range]
- Akomodasi: Rp [range]
- Kuliner: Rp [range]
- Aktivitas: Rp [range]

**💡 Tips Penting**
- [Tip 1]
- [Tip 2]
- [Tip 3]

⚠️ WAJIB:
- HANYA BAHASA INDONESIA, tidak boleh Inggris
- RINGKAS & PRAKTIS, tidak perlu panjang
- Total output MAKSIMAL 2000 KARAKTER''';

      final response = await http
          .post(
            Uri.parse(_groqApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Anda adalah travel expert Indonesia. RESPONS SINGKAT & PRAKTIS dalam Bahasa Indonesia saja. Output MAKSIMAL 2000 karakter. Jangan panjang-panjang, efisien saja.',
                },
                {
                  'role': 'user',
                  'content': prompt,
                }
              ],
              'temperature': 0.7,
              'max_tokens': 850, // Lebih ketat lagi
            }),
          )
          .timeout(
            Duration(seconds: 45),
            onTimeout: () => http.Response(
              'Error: Request timeout',
              504,
            ),
          );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String text = jsonResponse['choices'][0]['message']['content'];
        
        // Validasi panjang output
        text = _truncateToMaxLength(text, MAX_OUTPUT_LENGTH);
        
        return text;
      } else if (response.statusCode == 401) {
        return '❌ Error: API Key invalid atau expired!\n\n'
            'Solusi:\n'
            '1. Buka https://console.groq.com\n'
            '2. Copy API key yang benar\n'
            '3. Update di ai_helper.dart';
      } else {
        final errorBody = jsonDecode(response.body);
        return 'Error: ${errorBody['error']['message'] ?? 'Unknown error'}';
      }
    } catch (e) {
      return '❌ Error: $e';
    }
  }

  /// Memotong text agar tidak melebihi max length
  /// Jika dipotong, tambahkan "..." di akhir
  static String _truncateToMaxLength(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }

    // Potong pada maxLength dan cari kalimat terakhir yang lengkap
    String truncated = text.substring(0, maxLength);
    
    // Cari titik terakhir sebelum truncate
    int lastPeriodIndex = truncated.lastIndexOf('.');
    if (lastPeriodIndex > maxLength - 100) {
      // Jika ada titik dalam 100 karakter terakhir, gunakan itu
      return truncated.substring(0, lastPeriodIndex + 1);
    }
    
    // Jika tidak ada, cari newline terakhir
    int lastNewlineIndex = truncated.lastIndexOf('\n');
    if (lastNewlineIndex > 0) {
      return truncated.substring(0, lastNewlineIndex);
    }
    
    // Jika tidak ada, potong saja dan tambah ...
    return truncated + '...';
  }
}