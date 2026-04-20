import 'package:flutter/material.dart';
import 'helpers/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  // Kembali seperti bawaan asli Flutter, tidak ada yang diubah di sini!
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // Constructor tetap kosong, jadi file test tidak akan error
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoloTrek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // Kita gunakan FutureBuilder sebagai 'penjaga pintu'
      home: FutureBuilder<Map<String, dynamic>?>(
        future: DatabaseHelper().getCurrentSession(), // Cek SQLite
        builder: (context, snapshot) {
          // 1. Jika aplikasi masih loading mengecek database, tampilkan indikator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // 2. Jika pengecekan selesai dan DITEMUKAN sesi tersimpan
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          
          // 3. Jika pengecekan selesai dan TIDAK ADA sesi (null)
          return const LoginScreen();
        },
      ),
    );
  }
}