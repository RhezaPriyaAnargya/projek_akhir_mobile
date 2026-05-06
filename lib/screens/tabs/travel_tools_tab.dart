import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../../helpers/app_colors.dart';
import '../../helpers/compass_painter.dart';

class TravelToolsTab extends StatefulWidget {
  const TravelToolsTab({super.key});

  @override
  State<TravelToolsTab> createState() => _TravelToolsTabState();
}

class _TravelToolsTabState extends State<TravelToolsTab>
    with AutomaticKeepAliveClientMixin {
  // ── Pedometer ──
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  int _steps = 0;
  String _status = 'stopped';
  static const double _strideM = 0.762;
  static const double _calPerStep = 0.04;

  // ── Kompas + Kiblat ──
  StreamSubscription<MagnetometerEvent>? _magSub;
  double _heading = 0;
  double _qiblaAngle = 0;
  bool _locationLoaded = false;
  String _locationStatus = 'Mendeteksi lokasi...';
  int _initialSteps = 0;

  static const double _mekkahLat = 21.4225;
  static const double _mekkahLng = 39.8262;

  // ── ML Kit Translator ──
  File? _pickedImage;
  String _ocrText = '';
  String _detectedLang = '';
  String _detectedLangName = '';
  String _translatedText = '';
  bool _isProcessing = false;
  bool _isDownloadingModel = false;
  String _mlStatus = '';
  final ImagePicker _imagePicker = ImagePicker();

  // Map kode bahasa → nama bahasa
  static const Map<String, String> _langNames = {
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

  // Map kode bahasa ML Kit Language ID → TranslateLanguage
  static const Map<String, TranslateLanguage> _langToTranslate = {
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initPedometer();
    _initCompass();
    _initLocation();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  // ── Pedometer ──────────────────────────────────────────────────
  void _initPedometer() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      setState(() => _status = 'permission denied');
      return;
    }
    _stepSub = Pedometer.stepCountStream.listen((e) {
      if (_initialSteps == 0) _initialSteps = e.steps;
      setState(() => _steps = e.steps - _initialSteps);
    });
    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (e) => setState(() => _status = e.status),
      onError: (_) {},
    );
  }

  // ── Kompas ─────────────────────────────────────────────────────
  void _initCompass() {
    _magSub = magnetometerEventStream().listen((e) {
      double angle = math.atan2(e.x, e.y) * (180 / math.pi);
      angle = (360 - angle) % 360;
      setState(() => _heading = angle);
    });
  }

  Future<void> _initLocation() async {
    setState(() {
      _locationLoaded = false;
      _locationStatus = 'Mendeteksi lokasi...';
    });
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _locationStatus = 'Layanan lokasi tidak aktif');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _locationStatus = 'Izin lokasi ditolak');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final qibla = _calcQibla(pos.latitude, pos.longitude);
      setState(() {
        _qiblaAngle = qibla;
        _locationLoaded = true;
        _locationStatus =
            '${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°';
      });
    } catch (_) {
      setState(() => _locationStatus = 'Gagal mendapatkan lokasi');
    }
  }

  double _calcQibla(double lat, double lng) {
    final latR = lat * math.pi / 180;
    final lngR = lng * math.pi / 180;
    final mLatR = _mekkahLat * math.pi / 180;
    final mLngR = _mekkahLng * math.pi / 180;
    final dLng = mLngR - lngR;
    final y = math.sin(dLng) * math.cos(mLatR);
    final x =
        math.cos(latR) * math.sin(mLatR) -
        math.sin(latR) * math.cos(mLatR) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double get _distanceKm => (_steps * _strideM) / 1000;
  double get _calories => _steps * _calPerStep;
  double get _needleAngle => (_qiblaAngle - _heading) * math.pi / 180;

  // ── ML Kit: Ambil foto & proses ────────────────────────────────
  Future<void> _pickAndProcess(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _pickedImage = File(picked.path);
        _ocrText = '';
        _detectedLang = '';
        _detectedLangName = '';
        _translatedText = '';
        _isProcessing = true;
        _mlStatus = '🔍 Membaca teks dari foto...';
      });

      // Step 1: OCR
      final inputImage = InputImage.fromFile(_pickedImage!);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognized = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final rawText = recognized.text.trim();

      if (rawText.isEmpty) {
        setState(() {
          _isProcessing = false;
          _mlStatus = '⚠️ Tidak ada teks yang terdeteksi di foto ini';
          _ocrText = '';
        });
        return;
      }

      setState(() {
        _ocrText = rawText;
        _mlStatus = '🌐 Mendeteksi bahasa...';
      });

      // Step 2: Deteksi Bahasa
      final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
      final langCode = await languageIdentifier.identifyLanguage(rawText);
      await languageIdentifier.close();

      final langName =
          _langNames[langCode] ?? 'Bahasa tidak dikenal ($langCode)';

      setState(() {
        _detectedLang = langCode;
        _detectedLangName = langName;
        _mlStatus = '📥 Menyiapkan model terjemahan...';
        _isDownloadingModel = true;
      });

      // Step 3: Translate ke Indonesia
      if (langCode == 'id' || langCode == 'und') {
        setState(() {
          _translatedText = langCode == 'id'
              ? '(Teks sudah dalam Bahasa Indonesia)'
              : '(Bahasa tidak dapat diidentifikasi)';
          _isProcessing = false;
          _isDownloadingModel = false;
          _mlStatus = '✅ Selesai!';
        });
        return;
      }

      final sourceLang =
          _langToTranslate[langCode] ?? TranslateLanguage.english;
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
        setState(() => _mlStatus = '📥 Mengunduh model bahasa $langName...');
        await modelManager.downloadModel(sourceLang.bcpCode);
      }

      setState(() {
        _isDownloadingModel = false;
        _mlStatus = '✍️ Menerjemahkan...';
      });

      final translated = await translator.translateText(rawText);
      await translator.close();

      setState(() {
        _translatedText = translated;
        _isProcessing = false;
        _mlStatus = '✅ Selesai!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isDownloadingModel = false;
        _mlStatus = '❌ Error: $e';
      });
    }
  }

  void _resetTranslator() {
    setState(() {
      _pickedImage = null;
      _ocrText = '';
      _detectedLang = '';
      _detectedLangName = '';
      _translatedText = '';
      _isProcessing = false;
      _isDownloadingModel = false;
      _mlStatus = '';
    });
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _secHeader(
          Icons.directions_walk,
          'Deteksi Langkah Kaki',
          AppColors.success,
        ),
        const SizedBox(height: 10),
        _pedometerCard(),
        const SizedBox(height: 24),
        _secHeader(Icons.explore, 'Kompas Arah Kiblat', AppColors.qiblaGold),
        const SizedBox(height: 10),
        _qiblaCard(),
        const SizedBox(height: 24),

        // ── TAMBAH: ML Translator Section ──────────────────────────
        _secHeader(
          Icons.translate_rounded,
          'Scan & Terjemahkan',
          AppColors.primary,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 10),
          child: Text(
            'Foto teks asing → deteksi bahasa → terjemah ke Indonesia',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        _translatorCard(),

        // ─────────────────────────────────────────────────────────
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Widget: Translator Card ────────────────────────────────────
  Widget _translatorCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tombol Kamera & Galeri
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Kamera',
                  color: AppColors.primary,
                  onTap: _isProcessing
                      ? null
                      : () => _pickAndProcess(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeri',
                  color: AppColors.success,
                  onTap: _isProcessing
                      ? null
                      : () => _pickAndProcess(ImageSource.gallery),
                ),
              ),
            ],
          ),

          // Preview Foto
          if (_pickedImage != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _pickedImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],

          // Status Processing
          if (_mlStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _mlStatus,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Hasil OCR
          if (_ocrText.isNotEmpty) ...[
            const SizedBox(height: 14),
            _resultSection(
              icon: Icons.document_scanner_rounded,
              title: 'Teks Terdeteksi',
              color: Colors.blue.shade600,
              child: Text(
                _ocrText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // Bahasa Terdeteksi
          if (_detectedLangName.isNotEmpty) ...[
            const SizedBox(height: 10),
            _resultSection(
              icon: Icons.language_rounded,
              title: 'Bahasa Terdeteksi',
              color: Colors.purple.shade500,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      _detectedLangName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                  if (_isDownloadingModel) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Mengunduh model...',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Hasil Terjemahan
          if (_translatedText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _resultSection(
              icon: Icons.translate_rounded,
              title: 'Terjemahan (Indonesia)',
              color: AppColors.success,
              child: Text(
                _translatedText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // Tombol Reset
          if (_pickedImage != null && !_isProcessing) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _resetTranslator,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Scan Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultSection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // ── Widget Lama (tidak diubah) ──────────────────────────────────
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

  Widget _pedometerCard() {
    final isWalking = _status == 'walking';
    return _card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isWalking ? AppColors.successLight : AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isWalking
                    ? AppColors.success.withOpacity(0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isWalking
                        ? AppColors.success
                        : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isWalking ? 'Sedang Berjalan' : 'Berhenti',
                  style: TextStyle(
                    color: isWalking
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$_steps',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Text(
            'langkah',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  Icons.straighten,
                  '${_distanceKm.toStringAsFixed(2)} km',
                  'Jarak',
                  AppColors.primary,
                  AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statChip(
                  Icons.local_fire_department,
                  '${_calories.toStringAsFixed(1)} kkal',
                  'Kalori',
                  AppColors.danger,
                  AppColors.dangerLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _initialSteps = _initialSteps + _steps;
                setState(() => _steps = 0);
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Langkah'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    IconData icon,
    String value,
    String label,
    Color color,
    Color bg,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _qiblaCard() => _card(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _locationLoaded ? Icons.location_on : Icons.location_searching,
              color: _locationLoaded
                  ? AppColors.success
                  : AppColors.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              _locationStatus,
              style: TextStyle(
                color: _locationLoaded
                    ? AppColors.success
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!_locationLoaded)
          Column(
            children: [
              const SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.qiblaGold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _locationStatus,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: CompassPainter(
                    heading: _heading,
                    needleAngle: _needleAngle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.qiblaGoldLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.qiblaGold.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🕋', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'Kiblat: ${_qiblaAngle.toStringAsFixed(1)}°',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kompas: ${_heading.toStringAsFixed(1)}°',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Putar ponsel hingga jarum emas mengarah lurus ke atas',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _initLocation,
          icon: const Icon(Icons.my_location, size: 14),
          label: const Text('Perbarui Lokasi', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
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
