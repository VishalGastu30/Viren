import 'package:flutter_test/flutter_test.dart';
import 'package:viren/core/ingestion/csv_import_service.dart';
import 'package:viren/core/ingestion/broker_templates.dart';

// Mock dependencies
import 'package:viren/core/database/repositories/trade_repository.dart';
import 'package:viren/core/database/daos/import_dao.dart';
class MockTradeRepository extends Fake implements TradeRepository {}
class MockImportDao extends Fake implements ImportDao {}

void main() {
  group('CsvImportService Parsing & Core Logic', () {
    late CsvImportService service;
    late MockTradeRepository mockTradeRepo;
    late MockImportDao mockImportDao;

    setUp(() {
      mockTradeRepo = MockTradeRepository();
      mockImportDao = MockImportDao();
      service = CsvImportService(
        tradeRepository: mockTradeRepo,
        importDao: mockImportDao,
      );
    });

    test('parseRawCsv normalizes CR/LF and parses correctly', () {
      const csvText = "Symbol,Qty\r\nRELIANCE,10\rINFY,5\n";
      final rows = service.parseRawCsv(csvText);
      
      expect(rows.length, 3);
      expect(rows[0], ['Symbol', 'Qty']);
      expect(rows[1], ['RELIANCE', '10']);
      expect(rows[2], ['INFY', '5']);
    });

    test('detectTemplate matches Zerodha Tradebook', () {
      final headers = [
        'symbol', 'trade_type', 'quantity', 'price', 'trade_date', 'exchange', 'order_no'
      ];
      final template = service.detectTemplate(headers);
      
      expect(template, isNotNull);
      expect(template?.templateId, 'zerodha_tradebook');
    });

    test('dryRun successfully parses valid Zerodha format trades', () {
      const csvText = '''symbol,trade_type,quantity,price,trade_date,exchange,order_no
RELIANCE,buy,10,2450.50,2024-01-15,NSE,1234
INFY,sell,5.0,1500.0,2024-01-16,NSE,5678''';

      final template = zerodhaTradebookTemplate;
      final headers = service.parseRawCsv(csvText).first;
      final mapping = service.mapColumns(headers, template);

      final preview = service.dryRun(
        rawCsvText: csvText,
        columnMapping: mapping,
        template: template,
      );
      // removed print


      expect(preview.errors, isEmpty);
      expect(preview.trades.length, 2);
      
      final first = preview.trades[0];
      expect(first.symbol, 'RELIANCE');
      expect(first.quantity, 10.0);
      expect(first.pricePerUnit, 2450.50);
      
      // Since parsing '2024-01-15' might map to local 00:00 and then convert to UTC
      // or directly to UTC 00:00 depending on DateFormat vs DateTime.parse,
      // we check the year, month, day to be safe rather than exact UTC ISO string
      // which fluctuates on the test runner's local timezone.
      final dt = first.tradeTimestamp.toLocal();
      expect(dt.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
      
      expect(first.fieldConfidence, greaterThan(80)); // High confidence with template match
    });

    test('dryRun catches formatting errors and skips bad rows', () {
      const csvText = '''symbol,type,qty,price,date
RELIANCE,buy,10,2450,2024-01-15
BADROW,buy,-5,2450,2024-01-15
INFY,sell,5,NOT_A_NUMBER,2024-01-16''';

      final headers = service.parseRawCsv(csvText).first;
      final mapping = service.mapColumns(headers, null); // Generic mapping

      final preview = service.dryRun(
        rawCsvText: csvText,
        columnMapping: mapping,
      );

      // 1 valid, 2 invalid
      expect(preview.trades.length, 1);
      expect(preview.errors.length, 2);
      expect(preview.errors[0], contains('Quantity must be positive'));
      expect(preview.errors[1], contains('Cannot parse price'));
    });
  });
}
