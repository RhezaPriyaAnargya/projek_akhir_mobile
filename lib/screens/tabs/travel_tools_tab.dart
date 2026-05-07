import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../helpers/app_colors.dart';
import '../../helpers/compass_painter.dart';
import '../../helpers/pedometer_service.dart';
import '../../helpers/qibla_compass_service.dart';
import '../../helpers/translation_service.dart';

class TravelToolsTab extends StatefulWidget {
  const TravelToolsTab({super.key});

  @override
  State<TravelToolsTab> createState() => _TravelToolsTabState();
}

class _TravelToolsTabState extends State<TravelToolsTab>
    with AutomaticKeepAliveClientMixin {
  final PedometerService _pedometerService = PedometerService();
  final QiblaCompassService _qiblaService = QiblaCompassService();
  final TranslationService _translationService = TranslationService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() async {
    // Setup callbacks
    _pedometerService.onUpdate = (steps, status) => setState(() {});
    _qiblaService.onUpdate = (heading, qibla, loaded, locStatus) =>
        setState(() {});
    _translationService.onUpdate = () => setState(() {});

    await _pedometerService.init();
    _qiblaService.initCompass();
    await _qiblaService.refreshLocation();
  }

  @override
  void dispose() {
    _pedometerService.dispose();
    _qiblaService.dispose();
    super.dispose();
  }

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
        const SizedBox(height: 16),
      ],
    );
  }

  // ========================= UI Components =========================

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
    final isWalking = _pedometerService.status == 'walking';
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
            '${_pedometerService.steps}',
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
                  '${_pedometerService.distanceKm.toStringAsFixed(2)} km',
                  'Jarak',
                  AppColors.primary,
                  AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statChip(
                  Icons.local_fire_department,
                  '${_pedometerService.calories.toStringAsFixed(1)} kkal',
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
              onPressed: () => setState(() => _pedometerService.reset()),
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
  ) {
    return Container(
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
  }

  Widget _qiblaCard() => _card(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _qiblaService.locationLoaded
                  ? Icons.location_on
                  : Icons.location_searching,
              color: _qiblaService.locationLoaded
                  ? AppColors.success
                  : AppColors.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              _qiblaService.locationStatus,
              style: TextStyle(
                color: _qiblaService.locationLoaded
                    ? AppColors.success
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!_qiblaService.locationLoaded)
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
                _qiblaService.locationStatus,
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
                    heading: _qiblaService.heading,
                    needleAngle: _qiblaService.needleAngle,
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
                      'Kiblat: ${_qiblaService.qiblaAngle.toStringAsFixed(1)}°',
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
                'Kompas: ${_qiblaService.heading.toStringAsFixed(1)}°',
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
          onPressed: () async {
            await _qiblaService.refreshLocation();
            setState(() {});
          },
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

  Widget _translatorCard() {
    final t = _translationService;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Kamera',
                  color: AppColors.primary,
                  onTap: t.isProcessing
                      ? null
                      : () => t.pickAndProcess(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeri',
                  color: AppColors.success,
                  onTap: t.isProcessing
                      ? null
                      : () => t.pickAndProcess(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (t.pickedImage != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                t.pickedImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (t.statusMessage.isNotEmpty) ...[
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
                  if (t.isProcessing)
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
                      t.statusMessage,
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
          if (t.ocrText.isNotEmpty) ...[
            const SizedBox(height: 14),
            _resultSection(
              icon: Icons.document_scanner_rounded,
              title: 'Teks Terdeteksi',
              color: Colors.blue.shade600,
              child: Text(
                t.ocrText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (t.detectedLangName.isNotEmpty) ...[
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
                      t.detectedLangName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                  if (t.isDownloadingModel) ...[
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
          if (t.translatedText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _resultSection(
              icon: Icons.translate_rounded,
              title: 'Terjemahan (Indonesia)',
              color: AppColors.success,
              child: Text(
                t.translatedText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (t.pickedImage != null && !t.isProcessing) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => t.reset(),
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
