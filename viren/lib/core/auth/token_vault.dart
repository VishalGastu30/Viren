import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/field_encryptor.dart';
import '../security/key_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TokenVault — Secure specialized storage for sensitive OAuth tokens & PAN.
//
// All sensitive fields are encrypted with AES-256-GCM using the 
// Master Encryption Key (MEK) via FieldEncryptor *before* being
// stored in the platform's secure storage.
// ─────────────────────────────────────────────────────────────────────────────
class TokenVault {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _keyAccessToken = 'viren_oauth_access_token';
  static const String _keyRefreshToken = 'viren_oauth_refresh_token';
  static const String _keyTokenExpiry = 'viren_oauth_expiry';


  final FieldEncryptor _encryptor;

  TokenVault._(this._encryptor);

  static Future<TokenVault> create() async {
    final keyManager = await KeyManager.initialize();
    final encryptor = FieldEncryptor(keyManager);
    return TokenVault._(encryptor);
  }

  // ── Generic Secure Field Operations ────────────────────────────────────────

  Future<void> _writeEncrypted(String key, String value) async {
    final cipherText = _encryptor.encrypt(value);
    if (cipherText != null) {
      await _storage.write(key: key, value: cipherText);
    }
  }

  Future<String?> _readDecrypted(String key) async {
    final cipherText = await _storage.read(key: key);
    if (cipherText == null) return null;
    return _encryptor.decrypt(cipherText);
  }

  Future<void> _delete(String key) async {
    await _storage.delete(key: key);
  }

  // ── OAuth Tokens ─────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String? refreshToken,
    required DateTime expiry,
  }) async {
    await _writeEncrypted(_keyAccessToken, accessToken);
    if (refreshToken != null) {
      await _writeEncrypted(_keyRefreshToken, refreshToken);
    }
    await _storage.write(key: _keyTokenExpiry, value: expiry.toIso8601String());
  }

  Future<String?> getAccessToken() => _readDecrypted(_keyAccessToken);
  Future<String?> getRefreshToken() => _readDecrypted(_keyRefreshToken);
  
  Future<DateTime?> getTokenExpiry() async {
    final value = await _storage.read(key: _keyTokenExpiry);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> clearTokens() async {
    await _delete(_keyAccessToken);
    await _delete(_keyRefreshToken);
    await _delete(_keyTokenExpiry);
  }


}
