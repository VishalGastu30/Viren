import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _key = 'biometric_lock_enabled';
  final LocalAuthentication _auth = LocalAuthentication();

  // Check if device supports biometrics
  Future<bool> isDeviceBiometricCapable() async {
    final bool canCheck = await _auth.canCheckBiometrics;
    final bool isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  // Check if biometric lock is enabled in settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  // Prompt OS biometric dialog and return result
  Future<bool> authenticate({required String reason, bool biometricOnly = false}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      return false;
    }
  }

  // Enable biometric lock — only after successful auth
  Future<bool> enableBiometricLock() async {
    final bool verified = await authenticate(
      reason: 'Verify your identity to enable biometric lock',
      biometricOnly: false,
    );
    if (verified) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    }
    return verified;
  }

  // Disable biometric lock — only after successful auth
  Future<bool> disableBiometricLock() async {
    final bool verified = await authenticate(
      reason: 'Verify your identity to disable biometric lock',
      biometricOnly: false,
    );
    if (verified) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, false);
    }
    return verified;
  }
}
