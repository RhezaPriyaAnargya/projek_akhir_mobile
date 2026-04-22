import 'package:flutter/material.dart';
import '../../helpers/database_helper.dart'; // sesuaikan path kamu

class KesanScreen extends StatefulWidget {
  const KesanScreen({super.key});

  @override
  State<KesanScreen> createState() => _KesanScreenState();
}

class _KesanScreenState extends State<KesanScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kesanController = TextEditingController();
  final TextEditingController _saranController = TextEditingController();

  Widget _feedbackCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.comment, size: 16, color: Colors.blue),
              SizedBox(width: 6),
              Text('Kesan', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item['kesan'] ?? ''),

          const SizedBox(height: 8),

          Row(
            children: const [
              Icon(Icons.lightbulb, size: 16, color: Colors.orange),
              SizedBox(width: 6),
              Text('Saran', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item['saran'] ?? ''),

          const SizedBox(height: 8),

          Text(
            item['timestamp'] ?? '',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Color(0xFF2563EB)),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (value) =>
            value!.isEmpty ? 'Field tidak boleh kosong' : null,
      ),
    );
  }

  List<Map<String, dynamic>> _feedbackList = [];
  Future<void> _loadFeedbacks() async {
    final db = DatabaseHelper();
    final data = await db.getFeedbacks();

    setState(() {
      _feedbackList = data;
    });
  }

  bool _isLoading = false;

  Future<void> _simpanFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final db = DatabaseHelper();
    final session = await db.getCurrentSession();

    if (session == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User belum login')));
      return;
    }

    await db.insertFeedback({
      'user_id': session['user_id'],
      'kesan': _kesanController.text,
      'saran': _saranController.text,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _loadFeedbacks();

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kesan & Saran berhasil disimpan')),
    );

    _kesanController.clear();
    _saranController.clear();
  }

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  @override
  void dispose() {
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Colors.lightBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔹 HEADER
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.feedback, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Kesan & Saran TPM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔹 FORM CARD
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        const Text(
                          'Berikan Kesan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 🔸 KESAN FIELD
                        _inputField(
                          controller: _kesanController,
                          hint: 'Ceritakan pengalamanmu...',
                          icon: Icons.sentiment_satisfied_alt,
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Berikan Saran',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 🔸 SARAN FIELD
                        _inputField(
                          controller: _saranController,
                          hint: 'Saran untuk perbaikan...',
                          icon: Icons.lightbulb_outline,
                        ),

                        const SizedBox(height: 24),

                        // 🔥 BUTTON
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _simpanFeedback,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.zero,
                              elevation: 5,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Colors.lightBlue],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Simpan Feedback',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Riwayat Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        ..._feedbackList
                            .map((item) => _feedbackCard(item))
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
