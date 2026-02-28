import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provides the SharedPreferences instance synchronously.
// This must be overridden in providerScope in main.dart after await SharedPreferences.getInstance()
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// A notifier to hold and update the app's settings.
class SettingsNotifier extends Notifier<AppSettings> {
  static const _keyCalmMode = 'settings_calm_mode';
  static const _keyBiometricLock = 'settings_biometric_lock';
  static const _keyLockTimeoutIndex = 'settings_lock_timeout_index';
  static const _keyAlertSensitivity = 'settings_alert_sensitivity';
  static const _keyInsightFrequency = 'settings_insight_frequency';
  static const _keyHideLowConfidence = 'settings_hide_low_confidence';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    
    return AppSettings(
      isCalmMode: prefs.getBool(_keyCalmMode) ?? true,      // default to true
      biometricLock: prefs.getBool(_keyBiometricLock) ?? false,
      lockTimeoutIndex: prefs.getInt(_keyLockTimeoutIndex) ?? 1, // default 1 min
      alertSensitivity: prefs.getDouble(_keyAlertSensitivity) ?? 1.0, // balanced
      insightFrequencyIndex: prefs.getInt(_keyInsightFrequency) ?? 1, // normal
      hideLowConfidence: prefs.getBool(_keyHideLowConfidence) ?? false,
    );
  }

  Future<void> setCalmMode(bool value) async {
    state = state.copyWith(isCalmMode: value);
    await ref.read(sharedPreferencesProvider).setBool(_keyCalmMode, value);
  }

  Future<void> setBiometricLock(bool value) async {
    state = state.copyWith(biometricLock: value);
    await ref.read(sharedPreferencesProvider).setBool(_keyBiometricLock, value);
  }

  Future<void> setLockTimeoutIndex(int value) async {
    state = state.copyWith(lockTimeoutIndex: value);
    await ref.read(sharedPreferencesProvider).setInt(_keyLockTimeoutIndex, value);
  }

  Future<void> setAlertSensitivity(double value) async {
    state = state.copyWith(alertSensitivity: value);
    await ref.read(sharedPreferencesProvider).setDouble(_keyAlertSensitivity, value);
  }

  Future<void> setInsightFrequencyIndex(int value) async {
    state = state.copyWith(insightFrequencyIndex: value);
    await ref.read(sharedPreferencesProvider).setInt(_keyInsightFrequency, value);
  }

  Future<void> setHideLowConfidence(bool value) async {
    state = state.copyWith(hideLowConfidence: value);
    await ref.read(sharedPreferencesProvider).setBool(_keyHideLowConfidence, value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});

class AppSettings {
  final bool isCalmMode;
  final bool biometricLock;
  final int lockTimeoutIndex;
  final double alertSensitivity;
  final int insightFrequencyIndex;
  final bool hideLowConfidence;

  const AppSettings({
    required this.isCalmMode,
    required this.biometricLock,
    required this.lockTimeoutIndex,
    required this.alertSensitivity,
    required this.insightFrequencyIndex,
    required this.hideLowConfidence,
  });

  AppSettings copyWith({
    bool? isCalmMode,
    bool? biometricLock,
    int? lockTimeoutIndex,
    double? alertSensitivity,
    int? insightFrequencyIndex,
    bool? hideLowConfidence,
  }) {
    return AppSettings(
      isCalmMode: isCalmMode ?? this.isCalmMode,
      biometricLock: biometricLock ?? this.biometricLock,
      lockTimeoutIndex: lockTimeoutIndex ?? this.lockTimeoutIndex,
      alertSensitivity: alertSensitivity ?? this.alertSensitivity,
      insightFrequencyIndex: insightFrequencyIndex ?? this.insightFrequencyIndex,
      hideLowConfidence: hideLowConfidence ?? this.hideLowConfidence,
    );
  }
}
