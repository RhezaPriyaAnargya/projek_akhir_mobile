import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String _username = "Loading...";
  String? _avatarPath;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isBiometricEnabled = false;
  bool _isNotificationEnabled = true;
  int? _sessionId;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('notification_enabled') ?? true;
    });
  }

  Future<void> _loadProfileData() async {
    final session = await _dbHelper.getCurrentSession();
    if (session != null) {
      final avatar = await _dbHelper.getUserAvatar(session['username']);
      setState(() {
        _sessionId = session['id'];
        _username = session['username'];
        _isBiometricEnabled = session['is_biometric_enabled'] == 1;
        _avatarPath = avatar;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      final success = await _dbHelper.updateUserAvatar(_username, image.path);
      if (success) {
        setState(() {
          _avatarPath = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar berhasil diperbarui!')),
          );
        }
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_sessionId != null) {
      await _dbHelper.updateBiometricStatus(_sessionId!, value);
      setState(() {
        _isBiometricEnabled = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Login Sidik Jari Diaktifkan'
                  : 'Login Sidik Jari Dimatikan',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled', value);

    if (!value) {
      // Matikan semua notifikasi yang sudah terjadwal
      await NotificationHelper.cancelAllNotifications();
    }

    setState(() {
      _isNotificationEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? '🔔 Notifikasi Diaktifkan' : '🔕 Notifikasi Dimatikan',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _dbHelper.clearSession();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profil & Pengaturan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // --- FOTO PROFIL ---
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blueAccent,
                    backgroundImage:
                        _avatarPath != null && File(_avatarPath!).existsSync()
                        ? FileImage(File(_avatarPath!)) as ImageProvider
                        : null,
                    child:
                        _avatarPath == null || !File(_avatarPath!).existsSync()
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.blueAccent,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- USERNAME ---
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

            // --- TOGGLE NOTIFIKASI ---
            SwitchListTile(
              title: const Text(
                'Notifikasi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _isNotificationEnabled
                    ? 'Pengingat rencana perjalanan aktif'
                    : 'Notifikasi dimatikan',
              ),
              secondary: Icon(
                _isNotificationEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _isNotificationEnabled ? Colors.blueAccent : Colors.grey,
              ),
              value: _isNotificationEnabled,
              activeColor: Colors.blueAccent,
              onChanged: _toggleNotification,
            ),

            const Divider(thickness: 1),

            // --- TOGGLE BIOMETRIK ---
            SwitchListTile(
              title: const Text(
                'Login dengan Sidik Jari',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Gunakan biometrik untuk masuk lebih cepat'),
              secondary: const Icon(
                Icons.fingerprint,
                color: Colors.blueAccent,
              ),
              value: _isBiometricEnabled,
              activeColor: Colors.blueAccent,
              onChanged: _toggleBiometric,
            ),

            const Divider(thickness: 1),

            // --- LOGOUT ---
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Konfirmasi Logout'),
                    content: const Text(
                      'Apakah Anda yakin ingin keluar dari aplikasi?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _logout(context);
                        },
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.white),
                        ),
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
