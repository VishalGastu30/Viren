import '../database/enums.dart';
import '../database/repositories/trade_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ManualTradeService — Thin validation wrapper for hand-entered trades.
//
// Intentionally simple. The PRD says manual entry must bypass ingestion
// complexity while still passing through validation, encryption, and
// hash-chain updates. TradeRepository handles the heavy lifting.
// ─────────────────────────────────────────────────────────────────────────────

/// Validation errors for manual trade entry.
class TradeValidationError {
  final String field;
  final String message;
  const TradeValidationError(this.field, this.message);

  @override
  String toString() => '$field: $message';
}

class ManualTradeService {
  final TradeRepository _tradeRepo;

  ManualTradeService({
    required TradeRepository tradeRepository,
  }) : _tradeRepo = tradeRepository;

  /// Validates trade input and returns a list of errors.
  /// Returns empty list if valid.
  List<TradeValidationError> validate({
    required String instrumentSymbol,
    required String instrumentName,
    required TradeType tradeType,
    required double quantity,
    required double pricePerUnit,
    required DateTime tradeTimestamp,
    String? broker,
    double? charges,
  }) {
    final errors = <TradeValidationError>[];

    if (instrumentSymbol.trim().isEmpty) {
      errors.add(const TradeValidationError('symbol', 'Symbol is required'));
    }
    if (instrumentSymbol.trim().length > 50) {
      errors.add(const TradeValidationError('symbol', 'Symbol too long (max 50)'));
    }
    if (instrumentName.trim().isEmpty) {
      errors.add(const TradeValidationError('name', 'Instrument name is required'));
    }
    if (quantity <= 0) {
      errors.add(const TradeValidationError('quantity', 'Quantity must be positive'));
    }
    if (pricePerUnit <= 0) {
      errors.add(const TradeValidationError('price', 'Price must be positive'));
    }
    if (tradeTimestamp.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      errors.add(const TradeValidationError('date', 'Trade date cannot be in the future'));
    }
    if (charges != null && charges < 0) {
      errors.add(const TradeValidationError('charges', 'Charges cannot be negative'));
    }

    return errors;
  }

  /// Validates and inserts a manually entered trade.
  ///
  /// Returns the inserted trade (with decrypted reason) or throws if
  /// validation fails.
  ///
  /// This method handles:
  ///   • Input validation
  ///   • Encryption of sensitive fields (via TradeRepository)
  ///   • Hash-chain update (via TradeRepository)
  ///   • Holdings cache rebuild (via TradeRepository)
  Future<TradeWithReason> insertManualTrade({
    required String instrumentSymbol,
    required String instrumentName,
    String? exchange,
    required TradeType tradeType,
    required double quantity,
    required double pricePerUnit,
    required DateTime tradeTimestamp,
    String? broker,
    double? charges,
    String currency = 'INR',
    // Reason fields
    String? reasonText,
    List<String> tags = const [],
    EmotionalState? emotionalState,
    int? confidenceLevel,
  }) async {
    // 1. Validate
    final validationErrors = validate(
      instrumentSymbol: instrumentSymbol,
      instrumentName: instrumentName,
      tradeType: tradeType,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      tradeTimestamp: tradeTimestamp,
      broker: broker,
      charges: charges,
    );

    if (validationErrors.isNotEmpty) {
      throw ArgumentError(
        'Validation failed: ${validationErrors.join('; ')}',
      );
    }

    // 2. Insert via repository (handles encryption + hash chain + cache)
    final result = await _tradeRepo.insertTrade(
      instrumentSymbol: instrumentSymbol,
      instrumentName: instrumentName,
      exchange: exchange,
      tradeType: tradeType,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      broker: broker,
      charges: charges,
      currency: currency,
      source: TradeSource.manual,
      parseConfidence: 100, // manual entry = full confidence
      tradeTimestamp: tradeTimestamp,
      reasonText: reasonText,
      tags: tags,
      emotionalState: emotionalState,
      confidenceLevel: confidenceLevel,
    );

    return result;
  }
}
