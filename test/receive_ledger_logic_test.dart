import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/presentation/receive/receive_screen.dart';

void main() {
  group('Receive Ledger Logic', () {
    test('Payment-only entries are identified properly', () {
      final List<ReceiveEntry> entries = [
        ReceiveEntry(
          companyName: 'c1',
          id: '1',
          date: DateTime(2023, 1, 1),
          productName: 'Payment Only',
          price: 0,
          quantity: 0,
          totalAmount: 0,
          payment: 100,
          paymentDate: DateTime(2023, 1, 1),
        ),
        ReceiveEntry(
          companyName: 'c1',
          id: '2',
          date: DateTime(2023, 1, 2),
          productName: '',
          price: 0,
          quantity: 0,
          totalAmount: 0,
          payment: 200,
          paymentDate: DateTime(2023, 1, 2),
        )
      ];

      final rows = buildUiRows(entries);
      expect(rows.length, 2);
      expect(rows[0].isPaymentRow, isTrue);
      expect(rows[0].productName, isEmpty);
      expect(rows[1].isPaymentRow, isTrue);
      expect(rows[1].productName, isEmpty);
    });

    test('Same-day sorting order: stock deliveries appear before payments on the same date', () {
      final List<ReceiveEntry> entries = [
        ReceiveEntry(
          companyName: 'c1',
          id: 'pay',
          date: DateTime(2023, 1, 1, 12),
          productName: '',
          price: 0,
          quantity: 0,
          totalAmount: 0,
          payment: 50,
          paymentDate: DateTime(2023, 1, 1, 12),
        ),
        ReceiveEntry(
          companyName: 'c1',
          id: 'del',
          date: DateTime(2023, 1, 1, 15),
          productName: 'Fabric',
          price: 100,
          quantity: 1,
          totalAmount: 100,
          payment: 0,
        ),
      ];

      // Even though the delivery is at 15:00 and payment at 12:00,
      // on the same day, deliveries should come before payments.
      final rows = buildUiRows(entries);
      expect(rows.length, 2);
      expect(rows[0].id, 'del');
      expect(rows[0].isPaymentRow, isFalse);
      expect(rows[1].id, 'pay');
      expect(rows[1].isPaymentRow, isTrue);
    });

    test('Running balance properly adds stock total and deducts payments', () {
      final List<ReceiveEntry> entries = [
        ReceiveEntry(
          companyName: 'c1',
          id: '1',
          date: DateTime(2023, 1, 1),
          productName: 'Fabric A',
          price: 100,
          quantity: 2,
          totalAmount: 200, // Stock IN (adds to debt)
          payment: 50,      // Same-day payment (deducts from debt)
          paymentDate: DateTime(2023, 1, 1),
        ),
        ReceiveEntry(
          companyName: 'c1',
          id: '2',
          date: DateTime(2023, 1, 2),
          productName: '',
          price: 0,
          quantity: 0,
          totalAmount: 0,
          payment: 100, // Payment only (deducts from debt)
          paymentDate: DateTime(2023, 1, 2),
        )
      ];

      final rows = buildUiRows(entries);
      
      // Compute running balance as done in receive_screen.dart
      double runningBalance = 0;
      final balances = <double>[];
      
      for (final row in rows) {
        if (row.isPaymentRow) {
          runningBalance -= row.payment;
        } else {
          runningBalance += row.totalAmount;
          runningBalance -= row.payment; // same-day payment
        }
        balances.add(runningBalance);
      }

      // Expected:
      // Row 1 (Not payment only): +200 -50 = 150
      // Row 2 (Payment only): -100 -> 150 - 100 = 50
      
      expect(balances.length, 2);
      expect(balances[0], 150);
      expect(balances[1], 50);
    });
  });
}
