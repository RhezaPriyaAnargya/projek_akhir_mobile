import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'solotrek_local.db');
    return await openDatabase(
      path,
      version: 3, // Naikkan versi menjadi 3 untuk membuat tabel plans
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT 
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        username TEXT,
        is_biometric_enabled INTEGER DEFAULT 0,
        is_logged_in INTEGER DEFAULT 1 -- 1: Aktif, 0: Logout
      )
    ''');

    // Menambahkan tabel plans (Itinerary)
    await db.execute('''
      CREATE TABLE plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        title TEXT,
        date TEXT,
        location TEXT,
        details TEXT
      )
    ''');
  }

  // Jika aplikasi di-update, hapus tabel lama dan buat baru
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS plans'); // Hapus plans jika ada
    await db.execute('DROP TABLE IF EXISTS sessions');
    await db.execute('DROP TABLE IF EXISTS users');
    await _onCreate(db, newVersion);
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --- CRUD USERS ---
  Future<bool> registerUser(String username, String password) async {
    final db = await database;
    try {
      String hashedPassword = _hashPassword(password);
      await db.insert('users', {
        'username': username,
        'password': hashedPassword,
      });
      return true;
    } catch (e) {
      return false; 
    }
  }

  Future<bool> loginUser(String username, String password) async {
    final db = await database;
    String hashedPassword = _hashPassword(password);

    final List<Map<String, dynamic>> users = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, hashedPassword],
    );

    if (users.isNotEmpty) {
      // Hapus sesi milik akun lain agar HP hanya ingat 1 akun
      await db.delete('sessions', where: 'username != ?', whereArgs: [username]);
      
      // Cek apakah user ini sudah punya riwayat sesi
      final existingSession = await db.query('sessions', where: 'username = ?', whereArgs: [username]);

      if (existingSession.isNotEmpty) {
        // Jika sudah ada, cukup aktifkan status is_logged_in (Biometrik tetap aman)
        await db.update('sessions', {'is_logged_in': 1}, where: 'username = ?', whereArgs: [username]);
      } else {
        // Jika belum ada, buat sesi baru
        await db.insert('sessions', {
          'user_id': users.first['id'],
          'username': users.first['username'],
          'is_biometric_enabled': 0,
          'is_logged_in': 1
        });
      }
      return true;
    }
    return false;
  }

  // --- LOGIKA SESI BARU ---

  // Dipanggil saat aplikasi pertama dibuka (Hanya ambil yang sedang aktif)
  Future<Map<String, dynamic>?> getCurrentSession() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sessions', where: 'is_logged_in = 1', limit: 1);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // Dipanggil oleh Biometrik (Ambil sesi walau statusnya Logout)
  Future<Map<String, dynamic>?> getSavedSessionForBiometric() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sessions', limit: 1);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // Dipanggil jika login sidik jari sukses (Ubah status jadi aktif lagi)
  Future<void> reactivateSession() async {
    final db = await database;
    await db.update('sessions', {'is_logged_in': 1});
  }

  Future<int> updateBiometricStatus(int sessionId, bool isEnabled) async {
    final db = await database;
    return await db.update('sessions', {'is_biometric_enabled': isEnabled ? 1 : 0}, where: 'id = ?', whereArgs: [sessionId]);
  }

  // LOGOUT (Hanya mengubah status, tidak menghapus data)
  Future<int> clearSession() async {
    final db = await database;
    return await db.update('sessions', {'is_logged_in': 0});
  }

  // ==========================================
  // --- CRUD PLANS (RENCANA PERJALANAN) ---
  // ==========================================

  // Simpan Rencana Baru
  Future<int> insertPlan(Map<String, dynamic> plan) async {
    final db = await database;
    return await db.insert('plans', plan);
  }

  // Ambil Semua Rencana Milik User yang Sedang Login
  Future<List<Map<String, dynamic>>> getPlans() async {
    final db = await database;
    final session = await getCurrentSession();
    
    // Jika tidak ada user yang login, kembalikan list kosong
    if (session == null) return [];
    
    return await db.query(
      'plans', 
      where: 'user_id = ?', 
      whereArgs: [session['user_id']],
      orderBy: 'id DESC' // Urutkan dari yang terbaru
    );
  }

  // Hapus Rencana
  Future<int> deletePlan(int id) async {
    final db = await database;
    return await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  // Update Rencana (Edit)
  Future<int> updatePlan(Map<String, dynamic> plan) async {
    final db = await database;
    return await db.update(
      'plans',
      plan,
      where: 'id = ?',
      whereArgs: [plan['id']], // Cari berdasarkan ID
    );
  }
}