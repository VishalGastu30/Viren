import 'package:flutter_test/flutter_test.dart';
import 'package:viren/core/integrity/integrity_service.dart';

void main() {
  group('IntegrityService - Rolling Hash Chains', () {
    setUp(() {
      // Testing the pure hash math function, bypassing the DB constructor
      // since computeNextHash doesn't actually hit the DB directly in the core test
      // To test just the hashing logic we don't need a real DB.
    });

    test('Data normalization is deterministic and ordering-independent', () {
      final row1 = {
        'id': '123',
        'price': 100.5,
        'symbol': 'HDFC',
      };

      final row2 = {
        'symbol': 'HDFC',
        'id': '123',
        'price': 100.5,
      };

      // Ensure identical regardless of map entry order
      final hash1 = IntegrityService.computeStaticHash(row1, 'prevHashVal');
      final hash2 = IntegrityService.computeStaticHash(row2, 'prevHashVal');

      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2));
    });

    test('Modifying data completely changes hash (Avalanche effect)', () {
      final row = {
        'id': '123',
        'price': 100.5,
        'symbol': 'HDFC',
      };

      final hash1 = IntegrityService.computeStaticHash(row, 'prevHashVal');
      
      row['price'] = 100.6; // Tiny change
      final hash2 = IntegrityService.computeStaticHash(row, 'prevHashVal');

      expect(hash1, isNot(equals(hash2)));
    });

    test('Chain breaks if previous hash is tampered', () {
      final row = { 'id': '1' };
      
      final validChain = IntegrityService.computeStaticHash(row, 'validPrevHash');
      final brokenChain = IntegrityService.computeStaticHash(row, 'tamperedPrevHash');

      expect(validChain, isNot(equals(brokenChain)));
    });
  });
}
