import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'key_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FieldEncryptor — AES-256-GCM field-level encryption
//
// Every encrypted field stored in the DB uses the format:
//
//   base64( version_byte[1] | iv[12] | ciphertext[n] | auth_tag[16] )
//
// The version byte enables future algorithm rotation (e.g. v2 switches to
// ChaCha20-Poly1305) without re-encrypting all rows at once. Old rows retain
// their version byte and are decrypted with their original algorithm.
//
// Security guarantees:
//  • Unique 12-byte IV per encryption call — never reused.
//  • 16-byte GCM auth tag authenticates both ciphertext AND the version byte.
//  • At rest: the decrypt key never touches disk.
// ─────────────────────────────────────────────────────────────────────────────

/// Version byte constants — extend when adding new algorithms.
class _EncVersion {
  static const int v1 = 0x01; // AES-256-GCM
}

class FieldEncryptor {
  final KeyManager _keyManager;

  FieldEncryptor(this._keyManager);

  static const int _ivLength = 12; // GCM standard
  static const int _tagLength = 16; // 128-bit auth tag
  static const int _versionLength = 1;
  static const int _keyVersionLength = 1;

  // ── Encrypt ──────────────────────────────────────────────────────────────

  /// Encrypts [plaintext] and returns a base64-encoded blob safe for DB storage.
  String? encrypt(String? plaintext) {
    if (plaintext == null || plaintext.isEmpty) return null;

    final key = _keyManager.dataKey;
    final keyVersion = _keyManager.currentVersion;
    final iv = _keyManager.randomBytes(_ivLength);
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    // AAD includes algorithm version and key version to prevent tampering.
    final aad = Uint8List.fromList([_EncVersion.v1, keyVersion]);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // true = encrypt
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8, // tag size in bits
          iv,
          aad,
        ),
      );

    final ciphertextWithTag = cipher.process(plaintextBytes);

    // Layout: version[1] | key_version[1] | iv[12] | ciphertext+tag[n+16]
    final blob = Uint8List(
      _versionLength + _keyVersionLength + _ivLength + ciphertextWithTag.length,
    );
    blob[0] = _EncVersion.v1;
    blob[1] = keyVersion;
    blob.setRange(2, 2 + _ivLength, iv);
    blob.setRange(2 + _ivLength, blob.length, ciphertextWithTag);

    return base64.encode(blob);
  }

  // ── Decrypt ──────────────────────────────────────────────────────────────

  /// Decrypts a base64-encoded blob produced by [encrypt].
  String? decrypt(String? cipherBlob) {
    if (cipherBlob == null || cipherBlob.isEmpty) return null;

    final blob = base64.decode(cipherBlob);
    final version = blob[0];

    if (version == _EncVersion.v1) {
      return _decryptV1(blob);
    } else {
      throw ArgumentError('Unknown encryption algorithm version: 0x${version.toRadixString(16)}');
    }
  }

  String _decryptV1(Uint8List blob) {
    final keyVersion = blob[1];
    final key = _keyManager.getDataKey(keyVersion);
    final iv = blob.sublist(2, 2 + _ivLength);
    final ciphertextWithTag = blob.sublist(2 + _ivLength);
    final aad = Uint8List.fromList([_EncVersion.v1, keyVersion]);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false, // false = decrypt
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8,
          iv,
          aad,
        ),
      );

    // process() will throw InvalidCipherTextException if auth tag fails.
    final plainBytes = cipher.process(ciphertextWithTag);
    return utf8.decode(plainBytes);
  }
}
