import 'package:flutter_test/flutter_test.dart';
import 'package:viren/core/database/app_database.dart';
import 'package:viren/core/database/enums.dart';
import 'package:viren/core/intelligence/confidence_calculator.dart';
import 'package:viren/core/database/repositories/behavior_repository.dart';
class MockBehaviorRepository extends Fake implements BehaviorRepository {
  @override
  Future<ConfidenceMeterData> saveConfidenceSnapshot({
    required double score,
    required double strategyAdherence,
    required double consistency,
    required double emotionalStability,
  }) async {
    return ConfidenceMeterData(
      id: 'mock-id',
      score: score,
      strategyAdherence: strategyAdherence,
      consistency: consistency,
      emotionalStability: emotionalStability,
      calculatedAt: DateTime.now(),
    );
  }
}

void main() {
  group('ConfidenceCalculator', () {
    late ConfidenceCalculator calculator;
    late MockBehaviorRepository mockRepo;

    setUp(() {
      mockRepo = MockBehaviorRepository();
      calculator = ConfidenceCalculator(mockRepo);
    });

    test('Empty trades return 50/100 baseline score', () async {
      final result = await calculator.compute(
        trades: [],
        reasons: {},
        emotionalStates: {},
      );

      expect(result.compositeScore, 50.0);
      expect(result.strategyAdherence, 50.0);
      expect(result.consistency, 50.0);
      expect(result.emotionalStability, 50.0);
    });

    test('Perfect scores: reasons for all, consistent gaps, stable emotions', () async {
      final baseDate = DateTime.utc(2025, 1, 1);
      final trades = [
        _mockTrade('1', baseDate),
        _mockTrade('2', baseDate.add(const Duration(days: 7))),
        _mockTrade('3', baseDate.add(const Duration(days: 14))),
        _mockTrade('4', baseDate.add(const Duration(days: 21))),
      ];

      final reasons = {
        '1': 'Long detailed rationale here',
        '2': 'Long detailed rationale here',
        '3': 'Long detailed rationale here',
        '4': 'Long detailed rationale here',
      };

      final emotions = {
        '1': 'calm',
        '2': 'disciplined',
        '3': 'calm',
        '4': 'cautious',
      };

      final result = await calculator.compute(
        trades: trades,
        reasons: reasons,
        emotionalStates: emotions,
      );

      // Strategy: 100% have reasons, >10 chars -> 100
      expect(result.strategyAdherence, 100.0);
      // Consistency: exact 7-day gaps, variance 0, CV=0 -> 100
      expect(result.consistency, 100.0);
      // Emotions: 100% in stable set -> 100
      expect(result.emotionalStability, 100.0);
      
      expect(result.compositeScore, 100.0);
    });

    test('Poor scores: no reasons, chaotic gaps, fearful emotions', () async {
      final baseDate = DateTime.utc(2025, 1, 1);
      final trades = [
        _mockTrade('1', baseDate),
        _mockTrade('2', baseDate.add(const Duration(days: 1))),
        _mockTrade('3', baseDate.add(const Duration(days: 10))),
        _mockTrade('4', baseDate.add(const Duration(days: 60))),
      ];

      final reasons = <String, String>{}; // no reasons
      
      final emotions = {
        '1': 'fear',
        '2': 'panic',
        '3': 'greed',
        '4': 'fomo',
      };

      final result = await calculator.compute(
        trades: trades,
        reasons: reasons,
        emotionalStates: emotions,
      );

      // Strategy: 0% have reasons -> 0
      expect(result.strategyAdherence, 0.0);
      // Consistency: highly erratic gaps (1, 9, 50), high stddev -> very low score
      expect(result.consistency, lessThan(50.0));
      // Emotions: 0% in stable set -> 0
      expect(result.emotionalStability, 0.0);
      
      expect(result.compositeScore, lessThan(50.0));
    });
  });
}

Trade _mockTrade(String id, DateTime ts) {
  return Trade(
    id: id,
    instrumentSymbol: 'TEST',
    instrumentName: 'TEST',
    tradeType: TradeType.buy,
    quantity: 1,
    pricePerUnit: 100,
    totalValue: 100,
    tradeTimestamp: ts,
    broker: 'Mock',
    currency: 'INR',
    source: TradeSource.manual,
    status: TradeStatus.confirmed,
    parseConfidence: 100,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    tamperHash: '',
  );
}
