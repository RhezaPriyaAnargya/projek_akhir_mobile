import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../helpers/database_helper.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Key untuk Form Validasi
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final LocalAuthentication _localAuth = LocalAuthentication();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Cek form validasi
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    setState(() { _isLoading = true; });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    bool loginSuccess = await _dbHelper.loginUser(username, password);

    setState(() { _isLoading = false; });

    if (loginSuccess && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (mounted) {
      // Error handling jika akun tidak ditemukan / salah sandi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Username atau Password salah!')),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ... (Fungsi _handleBiometricLogin BIAKARKAN SAMA PERSIS SEPERTI SEBELUMNYA) ...
  Future<void> _handleBiometricLogin() async {
    try {
      final session = await _dbHelper.getSavedSessionForBiometric();
      
      if (session == null || session['is_biometric_enabled'] == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Sidik Jari belum aktif. Silakan login manual dan aktifkan di menu Profil.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perangkat tidak mendukung biometrik.')),
          );
        }
        return;
      }

      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Gunakan sidik jari untuk masuk sebagai ${session['username']}',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate && mounted) {
        await _dbHelper.reactivateSession();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error Biometrik: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          // Bungkus Column dengan Form
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.travel_explore, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'SoloTrek',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const Text('Smart Travel Planner', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 60),

                // Gunakan TextFormField
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Silakan masukkan username';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Silakan masukkan password';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24, width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                const Row(
                  children: [
                    Expanded(child: Divider(thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('atau masuk dengan', style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider(thickness: 1)),
                  ],
                ),
                const SizedBox(height: 24),

                Center(
                  child: InkWell(
                    onTap: _handleBiometricLogin,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue.shade200, width: 2),
                      ),
                      child: const Icon(Icons.fingerprint, size: 40, color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Belum punya akun?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text('Daftar di sini', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}