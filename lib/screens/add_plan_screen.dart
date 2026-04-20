import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';

class AddPlanScreen extends StatefulWidget {
  final Map<String, dynamic>? plan; // Tambahan: Untuk menerima data yang mau diedit

  const AddPlanScreen({super.key, this.plan});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _detailsController = TextEditingController();
  final _dbHelper = DatabaseHelper();

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  @override
  void initState() {
    super.initState();
    // Jika ada data yang dikirim (Mode Edit), isikan ke dalam kolom input
    if (widget.plan != null) {
      _titleController.text = widget.plan!['title'];
      _dateController.text = widget.plan!['date'];
      _detailsController.text = widget.plan!['details'];
    }
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
      });
    }
  }

  void _savePlan() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul Trip tidak boleh kosong!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final session = await _dbHelper.getCurrentSession();
    if (session != null) {
      if (widget.plan == null) {
        // MODE BUAT BARU (INSERT)
        await _dbHelper.insertPlan({
          'user_id': session['user_id'],
          'title': _titleController.text,
          'date': _dateController.text.isEmpty ? 'Tanggal belum ditentukan' : _dateController.text,
          'location': 'Yogyakarta',
          'details': _detailsController.text,
        });
      } else {
        // MODE EDIT (UPDATE)
        await _dbHelper.updatePlan({
          'id': widget.plan!['id'], // Ingat bawa ID-nya agar SQLite tahu mana yang diubah
          'user_id': session['user_id'],
          'title': _titleController.text,
          'date': _dateController.text,
          'location': widget.plan!['location'], // Pertahankan lokasi yang lama
          'details': _detailsController.text,
        });
      }
      if (mounted) Navigator.pop(context, true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ubah judul AppBar berdasarkan modenya
    bool isEditMode = widget.plan != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Rencana' : 'Buat Rencana Baru', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Judul Trip',
                  hintText: 'Cth: Liburan Musim Panas',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.flight),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _dateController,
                readOnly: true, 
                onTap: () => _selectDateRange(context), 
                decoration: InputDecoration(
                  labelText: 'Tanggal Perjalanan',
                  hintText: 'Pilih rentang tanggal...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  suffixIcon: const Icon(Icons.arrow_drop_down), 
                ),
              ),
              const SizedBox(height: 24),
              
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sabar, integrasi Trekker AI akan segera dipasang!')),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Isi Detail dengan Trekker AI', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blueAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _detailsController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Detail Perjalanan',
                  alignLabelWithHint: true, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 40), 
              
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _savePlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEditMode ? Colors.green : Colors.blueAccent, // Warna hijau jika Edit
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEditMode ? 'Update Rencana' : 'Simpan Rencana',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}