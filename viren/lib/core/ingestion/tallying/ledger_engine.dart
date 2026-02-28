import '../../database/enums.dart';
import '../email/broker_email_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LedgerEngine — Master Holdings Reconstructor
//
// Rules:
// 1. Transactions dictate Holdings. Start from 0, add BUY, subtract SELL.
// 2. A negative balance throws an explicit ledger error.
// 3. Price is attributed by prioritizing high-confidence execution nodes.
// 4. Snapshots are used strictly for cross-checking, NEVER to generate trades.
// ─────────────────────────────────────────────────────────────────────────────

class LedgerEngineException implements Exception {
  final String message;
  LedgerEngineException(this.message);
  @override
  String toString() => 'LedgerEngine Exception: $message';
}

/// Represents the reconstructed state of a given symbol.
class ReconstructedHolding {
  final String symbol;
  double netQuantity;
  double averagePrice;
  double totalInvested;

  ReconstructedHolding({
    required this.symbol,
    this.netQuantity = 0.0,
    this.averagePrice = 0.0,
    this.totalInvested = 0.0,
  });

  void applyBuy(double qty, double price) {
    if (qty <= 0) return;

    // Weighted average price calculation
    final totalCost = (netQuantity * averagePrice) + (qty * price);
    netQuantity += qty;
    averagePrice = totalCost / netQuantity;
    totalInvested += (qty * price);
  }

  void applySell(double qty, double price) {
    if (qty <= 0) return;

    if (netQuantity - qty < 0) {
      throw LedgerEngineException(
        'Negative balance violation for $symbol. Attempted to sell $qty but only have $netQuantity.',
      );
    }

    // Selling reduces quantity, average price remains the same (realized PnL is tracked externally if needed)
    netQuantity -= qty;
  }
}

class LedgerReconstructionResult {
  final Map<String, ReconstructedHolding> holdings;
  final List<EmailParsedTrade> validatedTrades;
  final List<String> discrepancies;
  final List<String> errors;

  const LedgerReconstructionResult({
    required this.holdings,
    required this.validatedTrades,
    required this.discrepancies,
    required this.errors,
  });
}

class LedgerEngine {
  /// Rebuilds holdings sequentially from a raw list of parsed trades.
  ///
  /// Inputs MUST be ordered by date.
  LedgerReconstructionResult reconstruct(List<EmailParseResult> parserResults) {
    final allTrades = <EmailParsedTrade>[];
    // EXPLICIT TYPING HERE TO FIX DART ANALYZER BUG
    final List<EmailParsedSnapshot> allSnapshots = <EmailParsedSnapshot>[];

    for (final res in parserResults) {
      allTrades.addAll(res.trades);
      allSnapshots.addAll(res.snapshots.whereType<EmailParsedSnapshot>());
    }

    // Sort strictly by execution date
    allTrades.sort((a, b) => a.tradeDate.compareTo(b.tradeDate));

    final holdings = <String, ReconstructedHolding>{};
    final validatedTrades = <EmailParsedTrade>[];
    final discrepancies = <String>[];
    final errors = <String>[];

    // 1. Process ledger sequentially
    for (final trade in allTrades) {
      // Deduplication strategy: Same symbol, exactly same date/time, same qty and tradeType is highly likely a duplicate.
      // V2 explicitly relies on NSE-Direct as ground truth, so we should prefer confidence > 90.
      if (trade.confidence < 90) {
        // Fallback trade (e.g. from CNB). Only apply if we haven't already processed an NSE Direct execution for this today.
        final exists = validatedTrades.whereType<EmailParsedTrade>().any(
          (EmailParsedTrade v) {
            final vd = v.tradeDate;
            final td = trade.tradeDate;
            return v.symbol == trade.symbol &&
                v.tradeType == trade.tradeType &&
                v.quantity == trade.quantity &&
                vd.year == td.year &&
                vd.month == td.month &&
                vd.day == td.day;
          },
        );
        if (exists) {
          // Skip fallback duplicate
          continue;
        }
      }

      holdings.putIfAbsent(
        trade.symbol,
        () => ReconstructedHolding(symbol: trade.symbol),
      );
      final holding = holdings[trade.symbol]!;

      try {
        if (trade.tradeType == TradeType.buy) {
          holding.applyBuy(trade.quantity, trade.pricePerUnit);
        } else if (trade.tradeType == TradeType.sell) {
          holding.applySell(trade.quantity, trade.pricePerUnit);
        }
        validatedTrades.add(trade);
      } catch (e) {
        errors.add(e.toString());
      }
    }

    // 2. Snapshot Cross-check Verification
    // Snapshots represent point-in-time balances. We will map the latest snapshot for each symbol and compare.
    final latestSnapshots = <String, EmailParsedSnapshot>{};
    for (final snap in allSnapshots) {
      if (snap.symbol != 'MARGIN_BALANCE') {
        final existing = latestSnapshots[snap.symbol];
        if (existing == null ||
            snap.snapshotDate.isAfter(existing.snapshotDate)) {
          latestSnapshots[snap.symbol] = snap;
        }
      }
    }

    for (final entry in latestSnapshots.entries) {
      final symbol = entry.key;
      final expectedQty = entry.value.quantity;

      final reconstructedQty = holdings[symbol]?.netQuantity ?? 0.0;

      if (reconstructedQty != expectedQty) {
        discrepancies.add(
          'Ledger mismatch for $symbol. Reconstructed: $reconstructedQty, Snapshot reports: $expectedQty.',
        );
      }
    }

    return LedgerReconstructionResult(
      holdings: holdings,
      validatedTrades: validatedTrades,
      discrepancies: discrepancies,
      errors: errors,
    );
  }
}
