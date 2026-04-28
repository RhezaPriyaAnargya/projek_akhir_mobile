import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'login_screen.dart';

typedef AvatarChangedCallback = void Function(String? newPath);

const Color _navy = Color(0xFF1A3557);
const Color _teal = Color(0xFF2ABFBF);
const Color _cream = Color(0xFFF5F0E8);

class ProfileScreen extends StatefulWidget {
  final AvatarChangedCallback? onAvatarChanged;

  const ProfileScreen({super.key, this.onAvatarChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String _username = 'Loading...';
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ),
              _bottomSheetTile(
                icon: Icons.photo_library_rounded,
                label: 'Pilih dari Galeri',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              _bottomSheetTile(
                icon: Icons.camera_alt_rounded,
                label: 'Ambil dari Kamera',
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Atur Foto Profil',
          toolbarColor: _navy,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: _teal,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
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
      widget.onAvatarChanged?.call(croppedFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_path_$_username', croppedFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Foto profil berhasil diperbarui!'),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              'Profil & Pengaturan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_navy, Color(0xFF254878)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Teal circle dekorasi
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _teal.withOpacity(0.15),
                      ),
                    ),
                  ),
                  // Avatar + nama
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _teal, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _navy.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 52,
                                  backgroundColor: _navy,
                                  backgroundImage:
                                      _avatarPath != null &&
                                          File(_avatarPath!).existsSync()
                                      ? FileImage(File(_avatarPath!))
                                            as ImageProvider
                                      : null,
                                  child:
                                      _avatarPath == null ||
                                          !File(_avatarPath!).existsSync()
                                      ? const Icon(
                                          Icons.person,
                                          size: 52,
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
                                  color: _teal,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Traveler SoloTrek',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // Ubah foto
                  Center(
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: _teal,
                        size: 16,
                      ),
                      label: const Text(
                        'Ubah Foto Profil',
                        style: TextStyle(color: _teal, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Pengaturan section ────────────────────────────
                  _sectionLabel('Pengaturan'),
                  const SizedBox(height: 10),
                  _settingsCard(
                    children: [
                      _settingsTile(
                        icon: _isNotificationEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        iconColor: _isNotificationEnabled ? _teal : Colors.grey,
                        title: 'Notifikasi',
                        subtitle: _isNotificationEnabled
                            ? 'Pengingat rencana perjalanan aktif'
                            : 'Notifikasi dimatikan',
                        trailing: Switch(
                          value: _isNotificationEnabled,
                          activeColor: _teal,
                          onChanged: _toggleNotification,
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),
                      _settingsTile(
                        icon: Icons.fingerprint_rounded,
                        iconColor: _navy,
                        title: 'Login Sidik Jari',
                        subtitle: 'Gunakan biometrik untuk masuk lebih cepat',
                        trailing: Switch(
                          value: _isBiometricEnabled,
                          activeColor: _teal,
                          onChanged: _toggleBiometric,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Akun section ──────────────────────────────────
                  _sectionLabel('Akun'),
                  const SizedBox(height: 10),
                  _settingsCard(
                    children: [
                      _settingsTile(
                        icon: Icons.logout_rounded,
                        iconColor: Colors.redAccent,
                        title: 'Logout',
                        subtitle: 'Keluar dari akun SoloTrek',
                        titleColor: Colors.redAccent,
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text(
                              'Konfirmasi Logout',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                            content: const Text(
                              'Apakah kamu yakin ingin keluar dari aplikasi?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // App version
                  Center(
                    child: Text(
                      'SoloTrek v1.0.0',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _navy,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: titleColor ?? _navy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing:
          trailing ??
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.grey.shade300,
          ),
    );
  }

  Widget _bottomSheetTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _teal, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w500, color: _navy),
      ),
    );
  }
}
