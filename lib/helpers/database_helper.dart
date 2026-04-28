import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'secure_storage_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // ============================================================
  // ENKRIPSI USERNAME — AES-256-CBC
  // Key & IV diambil dari Keychain/Keystore via SecureStorageHelper
  // ============================================================
  Future<String> _encryptUsername(String username) async {
    final key = enc.Key.fromUtf8(await SecureStorageHelper.getAesKey());
    final iv = enc.IV.fromUtf8(await SecureStorageHelper.getAesIV());
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.encrypt(username, iv: iv).base64;
  }

  Future<String> _decryptUsername(String encryptedUsername) async {
    final key = enc.Key.fromUtf8(await SecureStorageHelper.getAesKey());
    final iv = enc.IV.fromUtf8(await SecureStorageHelper.getAesIV());
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(
      enc.Encrypted.fromBase64(encryptedUsername),
      iv: iv,
    );
  }

  // ============================================================
  // HASH PASSWORD — SHA-256 + Salt
  // Salt diambil dari Keychain/Keystore via SecureStorageHelper
  // ============================================================
  Future<String> _hashPassword(String password) async {
    final salt = await SecureStorageHelper.getSalt();
    final bytes = utf8.encode(salt + password);
    return sha256.convert(bytes).toString();
  }

  // ============================================================

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

  // --- CRUD USERS ---

  Future<bool> registerUser(String username, String password) async {
    final db = await database;
    try {
      final encryptedUsername = await _encryptUsername(username);
      final hashedPassword = await _hashPassword(password);

      // 🔍 TEMPORARY LOG — hapus setelah testing selesai
      assert(() {
        print('=== DEBUG REGISTER ===');
        print('Username asli     : $username');
        print('Username enkripsi : $encryptedUsername');
        print('Password hash     : $hashedPassword');
        print('======================');
        return true;
      }());
      // 🔍 END LOG

      await db.insert('users', {
        'username': encryptedUsername, // ✅ AES-256-CBC
        'password': hashedPassword, // ✅ SHA-256 + Salt
      });
      return true;
    } catch (e) {
      print('Error register: $e');
      return false;
    }
  }

  Future<bool> loginUser(String username, String password) async {
    final db = await database;
    final allUsers = await db.query('users');

    Map<String, dynamic>? matchedUser;
    for (final user in allUsers) {
      final decrypted = await _decryptUsername(user['username'] as String);
      if (decrypted == username) {
        matchedUser = user;
        break;
      }
    }

    if (matchedUser == null) return false;
    if (matchedUser['password'] != await _hashPassword(password)) return false;

    final encryptedUsername = matchedUser['username'] as String;

    await db.delete(
      'sessions',
      where: 'username != ?',
      whereArgs: [encryptedUsername],
    );

    final existingSession = await db.query(
      'sessions',
      where: 'username = ?',
      whereArgs: [encryptedUsername],
    );

    if (existingSession.isNotEmpty) {
      await db.update(
        'sessions',
        {'is_logged_in': 1},
        where: 'username = ?',
        whereArgs: [encryptedUsername],
      );
    } else {
      await db.insert('sessions', {
        'user_id': matchedUser['id'],
        'username': encryptedUsername,
        'is_biometric_enabled': 0,
        'is_logged_in': 1,
      });
    }
    return true;
  }

  Future<bool> updateUserAvatar(String username, String avatarPath) async {
    final db = await database;
    final allUsers = await db.query('users');
    try {
      for (final user in allUsers) {
        final decrypted = await _decryptUsername(user['username'] as String);
        if (decrypted == username) {
          await db.update(
            'users',
            {'avatar_path': avatarPath},
            where: 'id = ?',
            whereArgs: [user['id']],
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getUserAvatar(String username) async {
    final db = await database;
    final allUsers = await db.query('users');
    try {
      for (final user in allUsers) {
        final decrypted = await _decryptUsername(user['username'] as String);
        if (decrypted == username) return user['avatar_path'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentSession() async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'is_logged_in = 1',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final session = Map<String, dynamic>.from(maps.first);
    session['username'] = await _decryptUsername(
      session['username'] as String,
    ); // ✅ dekripsi ke UI
    return session;
  }

  Future<Map<String, dynamic>?> getSavedSessionForBiometric() async {
    final db = await database;
    final maps = await db.query('sessions', limit: 1);
    if (maps.isEmpty) return null;
    final session = Map<String, dynamic>.from(maps.first);
    session['username'] = await _decryptUsername(session['username'] as String);
    return session;
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

  // --- CRUD PLANS ---

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
