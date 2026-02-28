import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/providers/database_providers.dart';
import 'integrity_service.dart';

enum VaultIntegrityState {
  healthy,
  tampered,
  unknown,
}

class VaultHealthStatus {
  final VaultIntegrityState state;
  final Map<String, bool> chainStatus;
  final DateTime lastChecked;

  VaultHealthStatus({
    required this.state,
    required this.chainStatus,
    required this.lastChecked,
  });

  bool get isHealthy => state == VaultIntegrityState.healthy;
}

class VaultHealthService {
  final AppDatabase _db;
  final IntegrityService _integrityService;

  VaultHealthService(this._db, this._integrityService);

  /// Verifies all critical chains in the database.
  Future<VaultHealthStatus> checkVaultHealth() async {
    final chainStatus = <String, bool>{};
    bool overallHealthy = true;

    // Verify 'trades' chain
    final trades = await _db.tradesDao.getAllTrades();
    final tradesHealthy = await _integrityService.verifyChain(
      'trades', 
      trades.map((t) => t.toJson()).toList(),
    );
    chainStatus['trades'] = tradesHealthy;
    if (!tradesHealthy) overallHealthy = false;

    // Verify 'alerts' chain
    final alerts = await _db.alertsDao.getAllAlerts();
    final alertsHealthy = await _integrityService.verifyChain(
      'alerts', 
      alerts.map((a) => a.toJson()).toList(),
    );
    chainStatus['alerts'] = alertsHealthy;
    if (!alertsHealthy) overallHealthy = false;

    // Verify 'trade_reasons' chain
    final reasons = await _db.tradesDao.getAllTradeReasons();
    final reasonsHealthy = await _integrityService.verifyChain(
      'trade_reasons', 
      reasons.map((r) => r.toJson()).toList(),
    );
    chainStatus['trade_reasons'] = reasonsHealthy;
    if (!reasonsHealthy) overallHealthy = false;

    return VaultHealthStatus(
      state: overallHealthy ? VaultIntegrityState.healthy : VaultIntegrityState.tampered,
      chainStatus: chainStatus,
      lastChecked: DateTime.now(),
    );
  }
}

final vaultHealthServiceProvider = Provider<VaultHealthService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final integrity = ref.watch(integrityServiceProvider);
  return VaultHealthService(db, integrity);
});

final vaultHealthStatusProvider = FutureProvider<VaultHealthStatus>((ref) async {
  final service = ref.watch(vaultHealthServiceProvider);
  return service.checkVaultHealth();
});
