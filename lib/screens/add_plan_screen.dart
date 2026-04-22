import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../helpers/database_helper.dart';
import '../helpers/ai_helper.dart';
import '../helpers/location_helper.dart';
import 'map_picker_screen.dart';

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

  // Error tracking
  String? _titleError;
  String? _dateError;
  String? _locationError;
  String? _detailsError;

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  // Konstanta validasi
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

    // Add listeners untuk real-time validation
    _titleController.addListener(_validateTitle);
    _locationController.addListener(_validateLocation);
    _detailsController.addListener(_validateDetails);
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
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      String start = "${picked.start.day} ${_months[picked.start.month - 1]}";
      String end = "${picked.end.day} ${_months[picked.end.month - 1]}";

      setState(() {
        if (start == end) {
          _dateController.text = start;
        } else {
          _dateController.text = "$start - $end";
        }
        _dateError = null;
      });
    }
  }

  Future<void> _generateAIDetails() async {
    if (_titleController.text.trim().isEmpty ||
        _dateController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi Judul, Tanggal, dan Lokasi terlebih dahulu!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingAI = true;
    });

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
          const SnackBar(
            content: Text('Detail berhasil di-generate!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingAI = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _savePlan() async {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi semua field dengan benar!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final session = await _dbHelper.getCurrentSession();
      if (session != null) {
        if (widget.plan == null) {
          await _dbHelper.insertPlan({
            'user_id': session['user_id'],
            'title': _titleController.text.trim(),
            'date': _dateController.text,
            'location': _locationController.text.trim(),
            'details': _detailsController.text.trim(),
          });
        } else {
          await _dbHelper.updatePlan({
            'id': widget.plan!['id'],
            'user_id': session['user_id'],
            'title': _titleController.text.trim(),
            'date': _dateController.text,
            'location': _locationController.text.trim(),
            'details': _detailsController.text.trim(),
          });
        }
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Session tidak ditemukan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditMode = widget.plan != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Rencana' : 'Buat Rencana Baru',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // JUDUL
              TextField(
                controller: _titleController,
                maxLength: MAX_TITLE_LENGTH,
                decoration: InputDecoration(
                  labelText: 'Judul Trip',
                  hintText: 'Cth: Liburan Musim Panas',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.flight),
                  errorText: _titleError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  counterText: '${_titleController.text.length}/$MAX_TITLE_LENGTH',
                ),
                onChanged: (_) => _validateTitle(),
              ),
              const SizedBox(height: 20),

              // TANGGAL
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: () => _selectDateRange(context),
                decoration: InputDecoration(
                  labelText: 'Tanggal Perjalanan',
                  hintText: 'Pilih rentang tanggal...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.calendar_today,
                    color: Colors.blueAccent,
                  ),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  errorText: _dateError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // LOKASI
              TextField(
                controller: _locationController,
                maxLength: MAX_LOCATION_LENGTH,
                decoration: InputDecoration(
                  labelText: 'Lokasi Perjalanan',
                  hintText: 'Cth: Bali, Yogyakarta, Jakarta...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.redAccent,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map, color: Colors.blueAccent),
                    onPressed: () async {
                      final selectedLocation = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPickerScreen(initialLocation: _selectedLocation),
                        ),
                      );
                      
                      if (selectedLocation != null) {
                        setState(() {
                          _selectedLocation = selectedLocation;
                          _locationController.text = LocationHelper.formatLocation(selectedLocation);
                          _validateLocation();
                        });
                      }
                    },
                  ),
                  errorText: _locationError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  counterText: '${_locationController.text.length}/$MAX_LOCATION_LENGTH',
                ),
                onChanged: (_) => _validateLocation(),
              ),
              const SizedBox(height: 24),

              // TOMBOL AI
              ElevatedButton.icon(
                onPressed: _isLoadingAI ? null : _generateAIDetails,
                icon: _isLoadingAI
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoadingAI
                      ? 'Menghasilkan Detail...'
                      : 'Isi Detail dengan Trekker AI',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: _isLoadingAI
                      ? Colors.grey
                      : Colors.blueAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // DETAIL PERJALANAN
              TextField(
                controller: _detailsController,
                maxLength: MAX_DETAILS_LENGTH,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Detail Perjalanan',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _detailsError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  counterText: '${_detailsController.text.length}/$MAX_DETAILS_LENGTH',
                ),
                onChanged: (_) => _validateDetails(),
              ),

              const SizedBox(height: 40),

              // TOMBOL SIMPAN
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isFormValid() ? _savePlan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid()
                        ? (isEditMode ? Colors.green : Colors.blueAccent)
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEditMode ? 'Update Rencana' : 'Simpan Rencana',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}