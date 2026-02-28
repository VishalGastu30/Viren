import '../../database/app_database.dart';
import '../../database/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Rule Engine — Deterministic Intelligence Framework
//
// All rules are:
//   • Deterministic — same input → same output
//   • Explainable — every alert includes the data that triggered it
//   • Offline-capable — no network required
//
// Rules produce RuleAlert objects which are persisted as Alerts via
// AlertRepository. The RuleEngine orchestrates execution of all registered
// rules against the current portfolio state.
// ─────────────────────────────────────────────────────────────────────────────

/// Context object passed to every rule. Contains all data needed for analysis.
/// Rules may read but NEVER write to the database.
class RuleContext {
  /// All trades, newest first.
  final List<Trade> trades;

  /// Current holdings (derived cache).
  final List<Holding> holdings;

  /// Historical behavioral metrics.
  final List<BehaviorMetric> behaviorMetrics;

  /// Latest confidence score, if any.
  final ConfidenceMeterData? latestConfidence;

  /// Import records (for lineage checks).
  final List<Import> imports;

  /// Current UTC time (for date calculations).
  final DateTime now;

  const RuleContext({
    required this.trades,
    required this.holdings,
    required this.behaviorMetrics,
    this.latestConfidence,
    required this.imports,
    DateTime? now,
  }) : now = now ?? const _DefaultNow();
}

/// Sentinel class to make now default to DateTime.now() at runtime.
class _DefaultNow implements DateTime {
  const _DefaultNow();
  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now().noSuchMethod(invocation);
}

/// Output of a single rule evaluation — one alert.
class RuleAlert {
  /// Unique identifier for this rule.
  final String ruleId;

  /// Severity of the alert.
  final AlertSeverity severity;

  /// Short headline.
  final String title;

  /// Full explanatory description.
  final String description;

  /// JSON-serializable evidence that triggered this alert.
  /// Stored for full explainability — the user can always see WHY.
  final Map<String, dynamic> triggerData;

  /// Confidence in this alert (0–100).
  final int confidence;

  /// Instrument this relates to, if specific. Null for portfolio-wide.
  final String? relatedInstrument;

  const RuleAlert({
    required this.ruleId,
    required this.severity,
    required this.title,
    required this.description,
    required this.triggerData,
    required this.confidence,
    this.relatedInstrument,
  });
}

/// Abstract base class for all intelligence rules.
abstract class IntelligenceRule {
  /// Machine-readable rule identifier (e.g. "ALLOCATION_DRIFT").
  String get ruleId;

  /// Human-readable display name.
  String get displayName;

  /// Evaluates this rule against the given context.
  /// Returns a list of alerts (empty if rule doesn't fire).
  List<RuleAlert> evaluate(RuleContext context);
}

/// The rule engine that orchestrates all registered rules.
class RuleEngine {
  final List<IntelligenceRule> _rules;

  RuleEngine(this._rules);

  /// Evaluates all registered rules and returns all generated alerts.
  List<RuleAlert> evaluateAll(RuleContext context) {
    final alerts = <RuleAlert>[];
    for (final rule in _rules) {
      try {
        alerts.addAll(rule.evaluate(context));
      } catch (_) {
        // Rule failures are silently swallowed — a broken rule must never
        // crash the app or block other rules from running.
      }
    }
    return alerts;
  }

  /// List of all registered rule IDs (for settings/toggle UI).
  List<String> get registeredRuleIds => _rules.map((r) => r.ruleId).toList();
}
