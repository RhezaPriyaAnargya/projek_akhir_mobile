import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'login_screen.dart';

// Callback global untuk update avatar di HomeView
typedef AvatarChangedCallback = void Function(String? newPath);

class ProfileScreen extends StatefulWidget {
  final AvatarChangedCallback? onAvatarChanged;

  const ProfileScreen({super.key, this.onAvatarChanged});

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
    // Pilih sumber foto
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pilih Foto Profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.blueAccent,
                ),
              ),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blueAccent),
              ),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image == null) return;

    // Crop foto 1:1
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Atur Foto Profil',
          toolbarColor: Colors.blueAccent,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.blueAccent,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Atur Foto Profil',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return;

    final success = await _dbHelper.updateUserAvatar(
      _username,
      croppedFile.path,
    );
    if (success) {
      setState(() => _avatarPath = croppedFile.path);

      // Notify HomeView untuk update avatar
      widget.onAvatarChanged?.call(croppedFile.path);

      // Simpan ke SharedPreferences agar HomeView bisa load tanpa relog
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_path_$_username', croppedFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_sessionId != null) {
      await _dbHelper.updateBiometricStatus(_sessionId!, value);
      setState(() => _isBiometricEnabled = value);
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
    if (!value) await NotificationHelper.cancelAllNotifications();
    setState(() => _isNotificationEnabled = value);
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
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.blueAccent,
                        backgroundImage:
                            _avatarPath != null &&
                                File(_avatarPath!).existsSync()
                            ? FileImage(File(_avatarPath!)) as ImageProvider
                            : null,
                        child:
                            _avatarPath == null ||
                                !File(_avatarPath!).existsSync()
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _pickImage,
              child: const Text(
                'Ubah Foto Profil',
                style: TextStyle(color: Colors.blueAccent, fontSize: 13),
              ),
            ),

            // --- USERNAME ---
            Text(
              _username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Traveler SoloTrek',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),

            const SizedBox(height: 32),
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
