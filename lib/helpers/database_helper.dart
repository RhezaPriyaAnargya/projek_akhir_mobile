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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        avatar_path TEXT DEFAULT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        username TEXT,
        is_biometric_enabled INTEGER DEFAULT 0,
        is_logged_in INTEGER DEFAULT 1
      )
    ''');

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

    await db.execute('''
      CREATE TABLE feedbacks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        kesan TEXT,
        saran TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS feedbacks');
    await db.execute('DROP TABLE IF EXISTS plans');
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
      await db.delete(
        'sessions',
        where: 'username != ?',
        whereArgs: [username],
      );

      final existingSession = await db.query(
        'sessions',
        where: 'username = ?',
        whereArgs: [username],
      );

      if (existingSession.isNotEmpty) {
        await db.update(
          'sessions',
          {'is_logged_in': 1},
          where: 'username = ?',
          whereArgs: [username],
        );
      } else {
        await db.insert('sessions', {
          'user_id': users.first['id'],
          'username': users.first['username'],
          'is_biometric_enabled': 0,
          'is_logged_in': 1,
        });
      }
      return true;
    }
    return false;
  }

  // Simpan path avatar ke database
  Future<bool> updateUserAvatar(String username, String avatarPath) async {
    final db = await database;
    try {
      await db.update(
        'users',
        {'avatar_path': avatarPath},
        where: 'username = ?',
        whereArgs: [username],
      );
      return true;
    } catch (e) {
      print('Error updating avatar: $e');
      return false;
    }
  }

  // Ambil avatar dari database
  Future<String?> getUserAvatar(String username) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result = await db.query(
        'users',
        columns: ['avatar_path'],
        where: 'username = ?',
        whereArgs: [username],
      );
      if (result.isNotEmpty) {
        return result.first['avatar_path'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting avatar: $e');
      return null;
    }
  }

  // --- LOGIKA SESI BARU ---

  Future<Map<String, dynamic>?> getCurrentSession() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'is_logged_in = 1',
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<Map<String, dynamic>?> getSavedSessionForBiometric() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> reactivateSession() async {
    final db = await database;
    await db.update('sessions', {'is_logged_in': 1});
  }

  Future<int> updateBiometricStatus(int sessionId, bool isEnabled) async {
    final db = await database;
    return await db.update(
      'sessions',
      {'is_biometric_enabled': isEnabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<int> clearSession() async {
    final db = await database;
    return await db.update('sessions', {'is_logged_in': 0});
  }

  // ==========================================
  // --- CRUD PLANS (RENCANA PERJALANAN) ---
  // ==========================================

  Future<int> insertPlan(Map<String, dynamic> plan) async {
    final db = await database;
    return await db.insert('plans', plan);
  }

  Future<List<Map<String, dynamic>>> getPlans() async {
    final db = await database;
    final session = await getCurrentSession();

    if (session == null) return [];

    return await db.query(
      'plans',
      where: 'user_id = ?',
      whereArgs: [session['user_id']],
      orderBy: 'id DESC',
    );
  }

  Future<int> deletePlan(int id) async {
    final db = await database;
    return await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updatePlan(Map<String, dynamic> plan) async {
    final db = await database;
    return await db.update(
      'plans',
      plan,
      where: 'id = ?',
      whereArgs: [plan['id']],
    );
  }

  Future<int> insertFeedback(Map<String, dynamic> feedback) async {
    final db = await database;
    return await db.insert('feedbacks', feedback);
  }

  Future<List<Map<String, dynamic>>> getFeedbacks() async {
    final db = await database;
    final session = await getCurrentSession();

    if (session == null) return [];

    return await db.query(
      'feedbacks',
      where: 'user_id = ?',
      whereArgs: [session['user_id']],
      orderBy: 'id DESC',
    );
  }
}