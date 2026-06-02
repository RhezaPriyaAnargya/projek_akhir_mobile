import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  final ImagePicker _imagePicker = ImagePicker();
  File? pickedImage;
  String ocrText = '';
  String detectedLang = '';
  String detectedLangName = '';
  String translatedText = '';
  bool isProcessing = false;
  bool isDownloadingModel = false;
  String statusMessage = '';

  // Callback untuk update UI
  Function()? onUpdate;

  // ── Mapping bahasa ─────────────────────────────────────────────
  static const Map<String, String> langNames = {
    'en': 'Inggris 🇬🇧',
    'ja': 'Jepang 🇯🇵',
    'ko': 'Korea 🇰🇷',
    'zh': 'Mandarin 🇨🇳',
    'ar': 'Arab 🇸🇦',
    'fr': 'Prancis 🇫🇷',
    'de': 'Jerman 🇩🇪',
    'es': 'Spanyol 🇪🇸',
    'it': 'Italia 🇮🇹',
    'pt': 'Portugis 🇵🇹',
    'ru': 'Rusia 🇷🇺',
    'th': 'Thailand 🇹🇭',
    'vi': 'Vietnam 🇻🇳',
    'ms': 'Melayu 🇲🇾',
    'id': 'Indonesia 🇮🇩',
    'hi': 'Hindi 🇮🇳',
    'tr': 'Turki 🇹🇷',
    'nl': 'Belanda 🇳🇱',
  };

  static const Map<String, TranslateLanguage> langToTranslate = {
    'en': TranslateLanguage.english,
    'ja': TranslateLanguage.japanese,
    'ko': TranslateLanguage.korean,
    'zh': TranslateLanguage.chinese,
    'ar': TranslateLanguage.arabic,
    'fr': TranslateLanguage.french,
    'de': TranslateLanguage.german,
    'es': TranslateLanguage.spanish,
    'it': TranslateLanguage.italian,
    'pt': TranslateLanguage.portuguese,
    'ru': TranslateLanguage.russian,
    'th': TranslateLanguage.thai,
    'vi': TranslateLanguage.vietnamese,
    'ms': TranslateLanguage.malay,
    'hi': TranslateLanguage.hindi,
    'tr': TranslateLanguage.turkish,
    'nl': TranslateLanguage.dutch,
  };

  // ── Script OCR yang didukung ML Kit ───────────────────────────
  // Setiap script dicoba satu per satu, ambil hasil terpanjang
  static const List<TextRecognitionScript> _scripts = [
    TextRecognitionScript.latin, // EN, ID, FR, DE, ES, dll
    TextRecognitionScript.japanese, // JA (juga bisa baca Chinese)
    TextRecognitionScript.korean, // KO
    TextRecognitionScript.chinese, // ZH
  ];

  // ── Multi-script OCR ──────────────────────────────────────────
  // Coba semua script, kembalikan teks terpanjang
  Future<String> _multiScriptOCR(InputImage inputImage) async {
    String bestText = '';

    for (final script in _scripts) {
      try {
        final recognizer = TextRecognizer(script: script);
        final result = await recognizer.processImage(inputImage);
        await recognizer.close();

        final text = result.text.trim();
        // Ambil hasil yang paling banyak karakternya
        if (text.length > bestText.length) {
          bestText = text;
        }
      } catch (_) {
        // Skip script yang error, lanjut ke berikutnya
        continue;
      }
    }

    return bestText;
  }

  // ── Main Process ──────────────────────────────────────────────
  Future<void> pickAndProcess(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      pickedImage = File(picked.path);
      ocrText = '';
      detectedLang = '';
      detectedLangName = '';
      translatedText = '';
      isProcessing = true;
      statusMessage = '🔍 Membaca teks dari foto...';
      _notifyUpdate();

      // ── Step 1: Multi-script OCR ──────────────────────────────
      final inputImage = InputImage.fromFile(pickedImage!);
      final rawText = await _multiScriptOCR(inputImage);

      if (rawText.isEmpty) {
        isProcessing = false;
        statusMessage = '⚠️ Tidak ada teks yang terdeteksi di foto ini';
        ocrText = '';
        _notifyUpdate();
        return;
      }

      ocrText = rawText;
      statusMessage = '🌐 Mendeteksi bahasa...';
      _notifyUpdate();

      // ── Step 2: Deteksi Bahasa ────────────────────────────────
      final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.4);
      final langCode = await languageIdentifier.identifyLanguage(rawText);
      await languageIdentifier.close();

      detectedLang = langCode;
      detectedLangName =
          langNames[langCode] ?? 'Bahasa tidak dikenal ($langCode)';
      statusMessage = '📥 Menyiapkan model terjemahan...';
      isDownloadingModel = true;
      _notifyUpdate();

      // Kalau sudah Indonesia atau tidak terdeteksi
      if (langCode == 'id' || langCode == 'und') {
        translatedText = langCode == 'id'
            ? '(Teks sudah dalam Bahasa Indonesia)'
            : '(Bahasa tidak dapat diidentifikasi)';
        isProcessing = false;
        isDownloadingModel = false;
        statusMessage = '✅ Selesai!';
        _notifyUpdate();
        return;
      }

      // ── Step 3: Translate ke Indonesia ───────────────────────
      final sourceLang = langToTranslate[langCode] ?? TranslateLanguage.english;
      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: TranslateLanguage.indonesian,
      );

      // Download model kalau belum ada
      final modelManager = OnDeviceTranslatorModelManager();
      final isDownloaded = await modelManager.isModelDownloaded(
        sourceLang.bcpCode,
      );
      if (!isDownloaded) {
        statusMessage = '📥 Mengunduh model bahasa $detectedLangName...';
        _notifyUpdate();
        await modelManager.downloadModel(sourceLang.bcpCode);
      }

      isDownloadingModel = false;
      statusMessage = '✍️ Menerjemahkan...';
      _notifyUpdate();

      final translated = await translator.translateText(rawText);
      await translator.close();

      translatedText = translated;
      isProcessing = false;
      statusMessage = '✅ Selesai!';
      _notifyUpdate();
    } catch (e) {
      isProcessing = false;
      isDownloadingModel = false;
      statusMessage = '❌ Error: $e';
      _notifyUpdate();
    }
  }

  void reset() {
    pickedImage = null;
    ocrText = '';
    detectedLang = '';
    detectedLangName = '';
    translatedText = '';
    isProcessing = false;
    isDownloadingModel = false;
    statusMessage = '';
    _notifyUpdate();
  }

  void _notifyUpdate() {
    onUpdate?.call();
  }
}
