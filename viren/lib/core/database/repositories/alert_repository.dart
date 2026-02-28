import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../daos/alerts_dao.dart';
import '../enums.dart';
import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertRepository — Immutable alert management.
// ─────────────────────────────────────────────────────────────────────────────
import '../../integrity/integrity_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertRepository — Immutable alert management.
// ─────────────────────────────────────────────────────────────────────────────
class AlertRepository {
  final AlertsDao _dao;
  final IntegrityService _integrityService;
  final _uuid = const Uuid();

  AlertRepository(this._dao, this._integrityService);

  /// Insert a new alert with the given fields.
  Future<Alert> insertAlert({
    required String alertType,
    required AlertSeverity severity,
    required String title,
    required String description,
    int confidence = 0,
    String? relatedInstrument,
    String triggerData = '{}',
    String? importId,
  }) async {
    final entry = AlertsCompanion.insert(
      id: _uuid.v4(),
      alertType: alertType,
      severity: severity,
      title: title,
      description: description,
      confidence: Value(confidence),
      relatedInstrument: Value(relatedInstrument),
      triggerData: Value(triggerData),
      importId: Value(importId),
      createdAt: Value(DateTime.now()),
    );

    // Compute tamper_hash for alerts chain
    final columns = entry.toColumns(true);
    final hash = await _integrityService.computeNextHash('alerts', _mapValueToString(columns));

    return _dao.insertAlert(entry.copyWith(tamperHash: Value(hash)));
  }

  /// Converts Drift column values to a simple Map for hashing.
  Map<String, dynamic> _mapValueToString(Map<String, Expression> columns) {
    final result = <String, dynamic>{};
    columns.forEach((key, value) {
      if (value is Variable) {
        result[key] = value.value?.toString() ?? 'NULL';
      }
    });
    return result;
  }

  /// Watch active (non-dismissed, non-snoozed) alerts.
  Stream<List<Alert>> watchActiveAlerts() => _dao.watchActiveAlerts();

  /// Watch all alert records including dismissed ones.
  Stream<List<Alert>> watchAllAlerts() => _dao.watchAllAlerts();

  /// Soft-dismiss an alert. Record remains immutable.
  Future<void> dismiss(String alertId) => _dao.dismissAlert(alertId);

  /// Snooze an alert until [until].
  Future<void> snooze(String alertId, DateTime until) =>
      _dao.snoozeAlert(alertId, until);
}
