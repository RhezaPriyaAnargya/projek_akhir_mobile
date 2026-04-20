import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  String _username = "Loading...";
  bool _isBiometricEnabled = false;
  int? _sessionId;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // Mengambil data user yang sedang login dari SQLite
  Future<void> _loadProfileData() async {
    final session = await _dbHelper.getCurrentSession();
    if (session != null) {
      setState(() {
        _sessionId = session['id'];
        _username = session['username'];
        _isBiometricEnabled = session['is_biometric_enabled'] == 1;
      });
    }
  }

  // Fungsi untuk mematikan/menghidupkan biometrik
  Future<void> _toggleBiometric(bool value) async {
    if (_sessionId != null) {
      await _dbHelper.updateBiometricStatus(_sessionId!, value);
      setState(() {
        _isBiometricEnabled = value;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Login Sidik Jari Diaktifkan' : 'Login Sidik Jari Dimatikan'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // Fungsi Logout
  Future<void> _logout(BuildContext context) async {
    await _dbHelper.clearSession();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, // Menghapus semua riwayat halaman
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profil & Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            
            // --- 1. FOTO PROFIL (Sesuai Kriteria Tugas) ---
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blueAccent,
                    // Kita gunakan icon dulu. Nanti bisa diganti NetworkImage/File
                    child: Icon(Icons.person, size: 60, color: Colors.white), 
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fitur ganti foto akan datang!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // --- 2. NAMA USERNAME ---
            Text(
              _username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Traveler SoloTrek',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            
            const SizedBox(height: 40),
            const Divider(thickness: 1),

            // --- 3. MENU PENGATURAN ---
            
            // Toggle Biometrik
            SwitchListTile(
              title: const Text('Login dengan Sidik Jari', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Gunakan biometrik untuk masuk lebih cepat'),
              secondary: const Icon(Icons.fingerprint, color: Colors.blueAccent),
              value: _isBiometricEnabled,
              activeColor: Colors.blueAccent,
              onChanged: _toggleBiometric,
            ),
            
            const Divider(thickness: 1),

            // Tombol Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                // Tampilkan dialog konfirmasi sebelum logout
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Konfirmasi Logout'),
                    content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () {
                          Navigator.pop(context); // Tutup dialog
                          _logout(context);       // Jalankan fungsi logout
                        },
                        child: const Text('Logout', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}