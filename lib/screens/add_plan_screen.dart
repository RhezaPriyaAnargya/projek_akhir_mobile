import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../helpers/database_helper.dart';
import '../helpers/ai_helper.dart';
import '../helpers/location_helper.dart';
import 'map_picker_screen.dart';
import '../helpers/notification_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _navy = Color(0xFF1A3557);
const Color _teal = Color(0xFF2ABFBF);
const Color _cream = Color(0xFFF5F0E8);

class AddPlanScreen extends StatefulWidget {
  final Map<String, dynamic>? plan;

  const AddPlanScreen({super.key, this.plan});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _detailsController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  bool _isLoadingAI = false;
  LatLng? _selectedLocation;

  String? _titleError;
  String? _dateError;
  String? _locationError;
  String? _detailsError;

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ags',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const int MAX_TITLE_LENGTH = 100;
  static const int MAX_LOCATION_LENGTH = 100;
  static const int MAX_DETAILS_LENGTH = 2000;

  @override
  void initState() {
    super.initState();
    if (widget.plan != null) {
      _titleController.text = widget.plan!['title'];
      _dateController.text = widget.plan!['date'];
      _locationController.text = widget.plan!['location'];
      _detailsController.text = widget.plan!['details'] ?? '';
    }
    _titleController.addListener(_validateTitle);
    _locationController.addListener(_validateLocation);
    _detailsController.addListener(_validateDetails);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _validateTitle() {
    setState(() {
      if (_titleController.text.isEmpty) {
        _titleError = 'Judul tidak boleh kosong';
      } else if (_titleController.text.length < 3) {
        _titleError = 'Judul minimal 3 karakter';
      } else if (_titleController.text.length > MAX_TITLE_LENGTH) {
        _titleError = 'Judul maksimal $MAX_TITLE_LENGTH karakter';
      } else {
        _titleError = null;
      }
    });
  }

  void _validateLocation() {
    setState(() {
      if (_locationController.text.isEmpty) {
        _locationError = 'Lokasi tidak boleh kosong';
      } else if (_locationController.text.length < 2) {
        _locationError = 'Lokasi minimal 2 karakter';
      } else if (_locationController.text.length > MAX_LOCATION_LENGTH) {
        _locationError = 'Lokasi maksimal $MAX_LOCATION_LENGTH karakter';
      } else {
        _locationError = null;
      }
    });
  }

  void _validateDetails() {
    setState(() {
      if (_detailsController.text.length > MAX_DETAILS_LENGTH) {
        _detailsError = 'Detail maksimal $MAX_DETAILS_LENGTH karakter';
      } else {
        _detailsError = null;
      }
    });
  }

  bool _isFormValid() {
    _validateTitle();
    _validateLocation();
    _validateDetails();
    return _titleError == null &&
        _locationError == null &&
        _detailsError == null &&
        _dateController.text.isNotEmpty;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: 'Pilih Tanggal Liburan',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      saveText: 'Simpan',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _navy,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      String start =
          "${picked.start.day} ${_months[picked.start.month - 1]} ${picked.start.year}";
      String end =
          "${picked.end.day} ${_months[picked.end.month - 1]} ${picked.end.year}";
      setState(() {
        _dateController.text = start == end ? start : "$start - $end";
        _dateError = null;
      });
    }
  }

  Future<void> _generateAIDetails() async {
    if (_titleController.text.trim().isEmpty ||
        _dateController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Isi Judul, Tanggal, dan Lokasi terlebih dahulu!',
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoadingAI = true);

    try {
      final details = await AIHelper.generateTravelDetails(
        _titleController.text,
        _dateController.text,
        _locationController.text,
      );
      setState(() {
        _isLoadingAI = false;
        _detailsController.text = details;
        _validateDetails();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Detail berhasil di-generate!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingAI = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _savePlan() async {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mohon lengkapi semua field dengan benar!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    try {
      final session = await _dbHelper.getCurrentSession();
      if (session != null) {
        final title = _titleController.text.trim();
        final date = _dateController.text;
        final location = _locationController.text.trim();

        final prefs = await SharedPreferences.getInstance();
        final notifEnabled = prefs.getBool('notification_enabled') ?? true;

        if (widget.plan == null) {
          await _dbHelper.insertPlan({
            'user_id': session['user_id'],
            'title': title,
            'date': date,
            'location': location,
            'details': _detailsController.text.trim(),
          });
          if (notifEnabled) {
            NotificationHelper.showPlanCreatedNotification(
              planTitle: title,
              planLocation: location,
            ).then((_) async {
              await Future.delayed(const Duration(seconds: 15));
              await NotificationHelper.scheduleH1Reminder(
                planTitle: title,
                planLocation: location,
                dateString: date,
              );
            });
          }
        } else {
          await NotificationHelper.cancelPlanNotifications(
            widget.plan!['title'] as String,
          );
          await _dbHelper.updatePlan({
            'id': widget.plan!['id'],
            'user_id': session['user_id'],
            'title': title,
            'date': date,
            'location': location,
            'details': _detailsController.text.trim(),
          });
          if (notifEnabled) {
            await NotificationHelper.scheduleH1Reminder(
              planTitle: title,
              planLocation: location,
              dateString: date,
            );
          }
        }

        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Session tidak ditemukan')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.plan != null;
    final formValid = _isFormValid();

    return Scaffold(
      backgroundColor: _cream,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_navy, Color(0xFF254878)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _teal.withOpacity(0.15),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditMode
                                    ? 'Edit Rencana'
                                    : 'Buat Rencana Baru',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isEditMode
                                    ? 'Perbarui detail perjalananmu'
                                    : 'Rencanakan petualangan berikutnya',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Form ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _navy.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Judul ─────────────────────────────────
                        _buildLabel(Icons.flight_takeoff_rounded, 'Judul Trip'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _titleController,
                          hint: 'Cth: Liburan Musim Panas',
                          icon: Icons.flight_takeoff_rounded,
                          maxLength: MAX_TITLE_LENGTH,
                          errorText: _titleError,
                          counterText:
                              '${_titleController.text.length}/$MAX_TITLE_LENGTH',
                          onChanged: (_) => _validateTitle(),
                        ),
                        const SizedBox(height: 18),

                        // ── Tanggal ───────────────────────────────
                        _buildLabel(
                          Icons.calendar_today_rounded,
                          'Tanggal Perjalanan',
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectDateRange(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _dateController.text.isNotEmpty
                                    ? _teal
                                    : Colors.grey.shade200,
                                width: _dateController.text.isNotEmpty
                                    ? 1.5
                                    : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: _navy.withOpacity(0.6),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _dateController.text.isNotEmpty
                                        ? _dateController.text
                                        : 'Pilih rentang tanggal...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _dateController.text.isNotEmpty
                                          ? _navy
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Lokasi ────────────────────────────────
                        _buildLabel(
                          Icons.location_on_rounded,
                          'Lokasi Perjalanan',
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _locationController,
                          hint: 'Cth: Bali, Yogyakarta, Jakarta...',
                          icon: Icons.location_on_rounded,
                          iconColor: _teal,
                          maxLength: MAX_LOCATION_LENGTH,
                          errorText: _locationError,
                          counterText:
                              '${_locationController.text.length}/$MAX_LOCATION_LENGTH',
                          onChanged: (_) => _validateLocation(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.map_rounded,
                              color: _navy.withOpacity(0.6),
                              size: 20,
                            ),
                            onPressed: () async {
                              final selectedLocation =
                                  await Navigator.push<LatLng>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapPickerScreen(
                                        initialLocation: _selectedLocation,
                                      ),
                                    ),
                                  );
                              if (selectedLocation != null) {
                                setState(() {
                                  _selectedLocation = selectedLocation;
                                  _locationController.text =
                                      LocationHelper.formatLocation(
                                        selectedLocation,
                                      );
                                  _validateLocation();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── AI Button ─────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _navy.withOpacity(0.07),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoadingAI ? null : _generateAIDetails,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _isLoadingAI
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _teal,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.auto_awesome,
                                        color: _teal,
                                        size: 20,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Trekker AI Assistant',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: _navy,
                                      ),
                                    ),
                                    Text(
                                      _isLoadingAI
                                          ? 'Sedang membuat detail...'
                                          : 'Isi detail perjalanan otomatis dengan AI',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.grey.shade300,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Detail Perjalanan ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _navy.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLabel(
                          Icons.description_rounded,
                          'Detail Perjalanan',
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _detailsController,
                          maxLength: MAX_DETAILS_LENGTH,
                          maxLines: 6,
                          style: const TextStyle(fontSize: 14, color: _navy),
                          decoration: InputDecoration(
                            hintText:
                                'Ceritakan rencana perjalananmu secara detail...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: const Color(0xFFF8F9FF),
                            errorText: _detailsError,
                            counterText:
                                '${_detailsController.text.length}/$MAX_DETAILS_LENGTH',
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _teal,
                                width: 1.5,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (_) => _validateDetails(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Simpan Button ─────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: formValid ? _savePlan : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEditMode
                            ? const Color(0xFF16A34A)
                            : _navy,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isEditMode
                                ? Icons.update_rounded
                                : Icons.save_rounded,
                            color: formValid ? Colors.white : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEditMode ? 'Update Rencana' : 'Simpan Rencana',
                            style: TextStyle(
                              color: formValid ? Colors.white : Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _teal, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    Color? iconColor,
    int? maxLength,
    String? errorText,
    String? counterText,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: _navy),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(
          icon,
          color: iconColor ?? _navy.withOpacity(0.6),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        errorText: errorText,
        counterText: counterText,
        filled: true,
        fillColor: const Color(0xFFF8F9FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
