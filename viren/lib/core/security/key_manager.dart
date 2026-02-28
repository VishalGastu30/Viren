import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KeyManager — Root of Trust
//
// Generates and stores the Master Encryption Key (MEK) on first launch.
// All derived keys (DATA, SYNC, BIOMETRIC) flow from the MEK via HKDF-SHA256.
//
// Security invariants:
//  • MEK is generated once, stored in platform secure enclave, never logged.
//  • Derived keys are computed in-memory on demand — never stored.
//  • If secure storage is unavailable, the app throws — no plaintext fallback.
// ─────────────────────────────────────────────────────────────────────────────
class KeyManager {
  static const _currentVersionKey = 'viren_mek_current_version';
  static const _mekPrefix = 'viren_mek_v';
  static const _keyLengthBytes = 32; // 256 bits

  static KeyManager? _instance;
  
  // Cache of MEK versions in memory
  static final Map<int, Uint8List> _mekCache = {};
  static int _currentVersion = 1;

  KeyManager._();

  /// Initialize the KeyManager. Must be called once at app startup.
  static Future<KeyManager> initialize() async {
    if (_instance != null) return _instance!;

    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );

    // Read current version
    final versionStr = await storage.read(key: _currentVersionKey);
    if (versionStr != null) {
      _currentVersion = int.parse(versionStr);
    } else {
      _currentVersion = 1;
      await storage.write(key: _currentVersionKey, value: '1');
    }

    // Load ALL known MEK versions into memory (securely)
    for (int v = 1; v <= _currentVersion; v++) {
      final key = '$_mekPrefix$v';
      final existing = await storage.read(key: key);
      if (existing != null) {
        _mekCache[v] = base64.decode(existing);
      } else if (v == 1) {
        // Bootstrap first key if missing
        final newMek = _generateSecureRandom(_keyLengthBytes);
        await storage.write(key: key, value: base64.encode(newMek));
        _mekCache[v] = newMek;
      }
    }

    _instance = KeyManager._();
    return _instance!;
  }

  /// The active MEK version to use for new encryptions.
  int get currentVersion => _currentVersion;

  /// Retrieves the data key for a specific MEK version.
  Uint8List getDataKey(int version) {
    final mek = _mekCache[version];
    if (mek == null) throw ArgumentError('MEK version v$version not found');
    return _deriveKey(mek, 'VIREN_DATA_KEY_V$version');
  }

  /// Retrieves the sync key for a specific MEK version.
  Uint8List getSyncKey(int version) {
    final mek = _mekCache[version];
    if (mek == null) throw ArgumentError('MEK version v$version not found');
    return _deriveKey(mek, 'VIREN_SYNC_KEY_V$version');
  }

  /// AES-256 key for current active version.
  Uint8List get dataKey => getDataKey(_currentVersion);

  /// Key reserved for future cloud sync.
  Uint8List get syncKey => getSyncKey(_currentVersion);

  /// Key used to wrap/unwrap the MEK.
  Uint8List get biometricWrapKey =>
      _deriveKey(_mekCache[_currentVersion]!, 'VIREN_BIOMETRIC_WRAP_KEY_V$_currentVersion');

  // ── HKDF derivation ──────────────────────────────────────────────────────

  /// Derives a 32-byte key from the MEK using HKDF-SHA256.
  /// [info] is a purpose-specific domain-separation label.
  static Uint8List _deriveKey(Uint8List ikm, String info) {
    final hkdf = HKDFKeyDerivator(SHA256Digest());
    hkdf.init(
      HkdfParameters(
        ikm,
        _keyLengthBytes,
        null, // no extra salt — the MEK itself is random
        Uint8List.fromList(utf8.encode(info)),
      ),
    );
    final output = Uint8List(_keyLengthBytes);
    hkdf.deriveKey(null, 0, output, 0);
    return output;
  }

  // ── Secure random ────────────────────────────────────────────────────────

  static Uint8List _generateSecureRandom(int lengthBytes) {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seed = Uint8List.fromList(
      List.generate(32, (_) => seedSource.nextInt(256)),
    );
    secureRandom.seed(KeyParameter(seed));
    return secureRandom.nextBytes(lengthBytes);
  }

  /// Generate a fresh cryptographically secure random byte array.
  /// Used by FieldEncryptor to produce unique IVs.
  Uint8List randomBytes(int length) => _generateSecureRandom(length);

  /// Wipes all in-memory MEKs.
  static void lockMemory() {
    if (_instance != null) {
      for (final mek in _mekCache.values) {
        mek.fillRange(0, mek.length, 0);
      }
      _mekCache.clear();
      _instance = null;
    }
  }

  /// Rotates the Master Encryption Key.
  /// 1. Generates a new MEK v(N+1).
  /// 2. Persists it in secure storage.
  /// 3. Updates the current version pointer.
  /// 4. Returns the new version number.
  Future<int> rotateMasterKey() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );

    final newVersion = _currentVersion + 1;
    final newKeyName = '$_mekPrefix$newVersion';
    final newMek = _generateSecureRandom(_keyLengthBytes);

    await storage.write(key: newKeyName, value: base64.encode(newMek));
    await storage.write(key: _currentVersionKey, value: newVersion.toString());

    _mekCache[newVersion] = newMek;
    _currentVersion = newVersion;

    return newVersion;
  }
}
