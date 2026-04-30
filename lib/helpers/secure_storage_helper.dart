import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';

class SecureStorageHelper {
  static const _storage = FlutterSecureStorage();

  static const _keyAES = 'aes_key';
  static const _keyIV = 'aes_iv';
  static const _keySalt = 'password_salt';

  // Generate random string dengan panjang tertentu
  static String _generateRandom(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Dipanggil sekali saat app pertama kali diinstall.
  /// Key akan di-generate otomatis & disimpan di Keychain/Keystore.
  static Future<void> initKeys() async {
    final existingKey = await _storage.read(key: _keyAES);
    if (existingKey != null) return; // sudah ada, skip

    await _storage.write(
      key: _keyAES,
      value: _generateRandom(32),
    ); // 32 byte = AES-256
    await _storage.write(
      key: _keyIV,
      value: _generateRandom(16),
    ); // 16 byte = CBC IV
    await _storage.write(
      key: _keySalt,
      value: _generateRandom(32),
    ); // salt bebas panjangnya
  }

  static Future<String> getAesKey() async =>
      (await _storage.read(key: _keyAES))!;
  static Future<String> getAesIV() async => (await _storage.read(key: _keyIV))!;
  static Future<String> getSalt() async =>
      (await _storage.read(key: _keySalt))!;
}
