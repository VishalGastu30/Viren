import 'parsers/sbi_nse_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReconciliationEngine — Compares statement holdings vs computed holdings.
//
// Takes statement data (from PDF) and local portfolio state, generates
// alerts for discrepancies. All corrective actions require user confirmation.
// ─────────────────────────────────────────────────────────────────────────────

/// A discrepancy found between statement and local holdings.
class ReconciliationAlert {
  final String symbol;
  final String? isin;
  final double statementQty;
  final double calculatedQty;
  final double delta;
  final String possibleReason;
  final String suggestedAction;
  final DateTime createdAt;

  const ReconciliationAlert({
    required this.symbol,
    this.isin,
    required this.statementQty,
    required this.calculatedQty,
    required this.delta,
    required this.possibleReason,
    required this.suggestedAction,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'isin': isin,
    'statement_qty': statementQty,
    'calculated_qty': calculatedQty,
    'delta': delta,
    'possible_reason': possibleReason,
    'suggested_action': suggestedAction,
    'created_at': createdAt.toIso8601String(),
  };
}

/// A local holding record for comparison.
class LocalHolding {
  final String symbol;
  final String? isin;
  final double quantity;
  final double avgCost;

  const LocalHolding({
    required this.symbol,
    this.isin,
    required this.quantity,
    required this.avgCost,
  });
}

class ReconciliationEngine {
  /// Tolerance for quantity mismatch (absolute shares)
  static const double quantityTolerance = 1.0;

  /// Reconcile statement holdings against locally tracked holdings.
  ///
  /// Returns a list of alerts for any discrepancies found.
  List<ReconciliationAlert> reconcile({
    required StatementParseResult statement,
    required List<LocalHolding> localHoldings,
  }) {
    final alerts = <ReconciliationAlert>[];
    final now = DateTime.now();

    // Build lookup map for local holdings
    final localMap = <String, LocalHolding>{};
    for (final h in localHoldings) {
      localMap[h.symbol.toUpperCase()] = h;
      if (h.isin != null) {
        localMap[h.isin!] = h;
      }
    }

    // Check each statement holding against local
    for (final sh in statement.holdings) {
      final key = sh.isin ?? sh.symbol.toUpperCase();
      final local = localMap[key] ?? localMap[sh.symbol.toUpperCase()];

      if (local == null) {
        // Holding in statement but not in local DB
        alerts.add(ReconciliationAlert(
          symbol: sh.symbol,
          isin: sh.isin,
          statementQty: sh.quantity,
          calculatedQty: 0,
          delta: sh.quantity,
          possibleReason: 'Holding exists in statement but not tracked locally. '
              'Possible missing trade imports or transfers.',
          suggestedAction: 'Review and create a synthetic entry for ${sh.quantity} shares of ${sh.symbol}.',
          createdAt: now,
        ));
      } else {
        final delta = (sh.quantity - local.quantity).abs();
        if (delta > quantityTolerance) {
          final direction = sh.quantity > local.quantity ? 'more' : 'fewer';
          alerts.add(ReconciliationAlert(
            symbol: sh.symbol,
            isin: sh.isin,
            statementQty: sh.quantity,
            calculatedQty: local.quantity,
            delta: sh.quantity - local.quantity,
            possibleReason: 'Statement shows ${sh.quantity} shares but local records show '
                '${local.quantity} shares ($direction). '
                'Possible causes: missing trade, partial fill, corporate action, or bonus.',
            suggestedAction: 'Locate the missing contract note or create an adjustment entry.',
            createdAt: now,
          ));
        }
      }

      // Remove from map so we can detect holdings in local but not in statement
      localMap.remove(key);
      localMap.remove(sh.symbol.toUpperCase());
    }

    // Holdings in local DB but not in statement
    // (Only flag if quantity > 0 — sold-off holdings won't appear in statement)
    for (final entry in localMap.entries) {
      if (entry.value.quantity > 0) {
        // Avoid duplicate alerts from ISIN+symbol double-entry
        final alreadyAlerted = alerts.any((a) =>
            a.symbol == entry.value.symbol || a.isin == entry.value.isin);
        if (!alreadyAlerted) {
          alerts.add(ReconciliationAlert(
            symbol: entry.value.symbol,
            isin: entry.value.isin,
            statementQty: 0,
            calculatedQty: entry.value.quantity,
            delta: -entry.value.quantity,
            possibleReason: 'Local records show ${entry.value.quantity} shares of '
                '${entry.value.symbol} but statement does not list this holding. '
                'Possible causes: sold off, transferred, or statement incomplete.',
            suggestedAction: 'Verify if shares were sold or transferred outside the app.',
            createdAt: now,
          ));
        }
      }
    }

    return alerts;
  }
}
