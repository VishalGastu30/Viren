import 'package:flutter_test/flutter_test.dart';
import 'package:viren/core/database/app_database.dart';
import 'package:viren/core/database/enums.dart';
import 'package:viren/core/intelligence/rules/rule_engine.dart';
import 'package:viren/core/intelligence/rules/allocation_drift_rule.dart';
import 'package:viren/core/intelligence/rules/avg_price_deviation_rule.dart';
import 'package:viren/core/intelligence/rules/inactivity_rule.dart';
import 'package:viren/core/intelligence/rules/overtrading_rule.dart';
import 'package:viren/core/intelligence/rules/dip_buy_pattern_rule.dart';

void main() {
  group('Rule Engine & Deterministic Rules', () {
    test('AllocationDriftRule alerts when single holding exceeds threshold', () {
      final rule = AllocationDriftRule(maxAllocationPercent: 25.0);

      // Create dummy holdings
      final holdings = <Holding>[
        Holding(
          instrumentSymbol: 'HDFC',
          instrumentName: 'HDFC Bank',
          totalQuantity: 10,
          averagePrice: 100,
          investedValue: 1000,
          lastUpdated: DateTime.now(),
        ),
        Holding(
          instrumentSymbol: 'RELIANCE',
          instrumentName: 'Reliance Industries',
          totalQuantity: 5,
          averagePrice: 800,
          investedValue: 4000, // 4000/5000 = 80% (exceeds 25%)
          lastUpdated: DateTime.now(),
        ),
      ];

      final context = RuleContext(
        trades: [],
        holdings: holdings,
        behaviorMetrics: [],
        imports: [],
      );

      final alerts = rule.evaluate(context);
      
      expect(alerts.length, 1);
      final alert = alerts.first;
      expect(alert.ruleId, 'ALLOCATION_DRIFT');
      expect(alert.relatedInstrument, 'RELIANCE');
      expect(alert.severity, AlertSeverity.critical); // > 40%
      expect(alert.triggerData['allocation_percent'], 80.0);
    });

    test('AvgPriceDeviationRule alerts on large price swings from average', () {
      final rule = AvgPriceDeviationRule(deviationThresholdPercent: 10.0);

      final holdings = <Holding>[
        Holding(
          instrumentSymbol: 'TCS',
          instrumentName: 'Tata Consultancy Services',
          totalQuantity: 10,
          averagePrice: 3000, // VWAP is 3000
          investedValue: 30000,
          lastUpdated: DateTime.now(),
        ),
      ];

      final trades = [
        Trade(
          id: '1',
          instrumentSymbol: 'TCS',
          instrumentName: 'TCS',
          tradeType: TradeType.buy,
          quantity: 2,
          pricePerUnit: 3450, // 15% above 3000
          totalValue: 6900,
          tradeTimestamp: DateTime.now(),
          broker: 'Zerodha',
          currency: 'INR',
          source: TradeSource.manual,
          status: TradeStatus.confirmed,
          parseConfidence: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tamperHash: '',
        ),
      ];

      final context = RuleContext(
        trades: trades,
        holdings: holdings,
        behaviorMetrics: [],
        imports: [],
      );

      final alerts = rule.evaluate(context);
      
      expect(alerts.length, 1);
      expect(alerts.first.ruleId, 'AVG_PRICE_DEVIATION');
      expect(alerts.first.triggerData['deviation_percent'], 15.0);
    });

    test('InactivityRule alerts when gap since last trade exceeds threshold', () {
      final rule = InactivityRule(inactivityDaysThreshold: 30);
      
      // Fixed time to make test deterministic
      final now = DateTime.utc(2025, 2, 1);
      
      final trades = [
        Trade(
          id: '1',
          instrumentSymbol: 'INFY',
          instrumentName: 'INFY',
          tradeType: TradeType.buy,
          quantity: 1,
          pricePerUnit: 1500,
          totalValue: 1500,
          // 32 days ago
          tradeTimestamp: DateTime.utc(2024, 12, 31),
          broker: 'Zerodha',
          currency: 'INR',
          source: TradeSource.manual,
          status: TradeStatus.confirmed,
          parseConfidence: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tamperHash: '',
        ),
      ];

      final context = RuleContext(
        trades: trades,
        holdings: [],
        behaviorMetrics: [],
        imports: [],
        now: now, // inject time
      );

      final alerts = rule.evaluate(context);
      
      expect(alerts.length, 1);
      expect(alerts.first.ruleId, 'INACTIVITY_GAP');
      expect(alerts.first.triggerData['gap_days'], 32);
    });

    test('OvertradingRule detects high frequency bursts', () {
      final rule = OvertradingRule(windowDays: 7, maxTradesInWindow: 3);

      final baseDate = DateTime.utc(2025, 1, 10);
      
      // 4 trades within 3 days
      final trades = [
        _mockTrade('1', baseDate),
        _mockTrade('2', baseDate.add(const Duration(days: 1))),
        _mockTrade('3', baseDate.add(const Duration(days: 2))),
        _mockTrade('4', baseDate.add(const Duration(days: 3))),
      ];

      final context = RuleContext(
        trades: trades,
        holdings: [],
        behaviorMetrics: [],
        imports: [],
      );

      final alerts = rule.evaluate(context);
      
      expect(alerts.length, 1);
      expect(alerts.first.ruleId, 'OVERTRADING');
      expect(alerts.first.triggerData['trade_count'], 4);
      expect(alerts.first.triggerData['window_days'], 7);
    });

    test('DipBuyPatternRule detects consecutive averaging down', () {
      final rule = DipBuyPatternRule(minConsecutiveDips: 3, windowDays: 30);
      final baseDate = DateTime.now().toUtc().subtract(const Duration(days: 15));

      final trades = [
        _mockTrade('1', baseDate, price: 100),
        _mockTrade('2', baseDate.add(const Duration(days: 1)), price: 90),
        _mockTrade('3', baseDate.add(const Duration(days: 2)), price: 80),
        _mockTrade('4', baseDate.add(const Duration(days: 3)), price: 70), // 4 total dips
      ];

      final context = RuleContext(
        trades: trades,
        holdings: [],
        behaviorMetrics: [],
        imports: [],
      );

      final alerts = rule.evaluate(context);
      
      expect(alerts.length, 1);
      expect(alerts.first.ruleId, 'DIP_BUY_PATTERN');
      expect(alerts.first.triggerData['consecutive_dips'], 4);
      expect(alerts.first.triggerData['first_dip_price'], 100.0);
      expect(alerts.first.triggerData['last_dip_price'], 70.0);
      expect(alerts.first.triggerData['total_decline_percent'], 30.0); // (100-70)/100
    });
  });
}

Trade _mockTrade(String id, DateTime ts, {double price = 100.0}) {
  return Trade(
    id: id,
    instrumentSymbol: 'TEST',
    instrumentName: 'TEST',
    tradeType: TradeType.buy,
    quantity: 1,
    pricePerUnit: price,
    totalValue: price,
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
