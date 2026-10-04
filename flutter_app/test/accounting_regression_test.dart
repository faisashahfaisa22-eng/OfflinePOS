import 'package:flutter_test/flutter_test.dart';
import 'package:qamvio_pos/core/business/accounting_rules.dart';

void main() {
  group('sale accounting invariants', () {
    test('credit sale produces due and consistent line totals', () {
      final items = <Map<String, Object?>>[
        {'qty': 2.0, 'price': 50.0, 'discount': 10.0},
        {'qty': 1.0, 'price': 25.0, 'discount': 0.0},
      ];
      final totals = AccountingRules.saleTotals(items: items, paid: 40);

      expect(totals.subtotal, 125);
      expect(totals.lineDiscount, 10);
      expect(totals.total, 115);
      expect(totals.due, 75);
      expect(totals.recovery, 0);

      final lineTotal = items.fold<double>(
        0,
        (sum, item) =>
            sum +
            (item['qty'] as double) * (item['price'] as double) -
            (item['discount'] as double),
      );
      expect(lineTotal, totals.total);
    });

    test('overpayment is represented as recovery', () {
      final totals = AccountingRules.saleTotals(
        items: [
          {'qty': 1.0, 'price': 10.0, 'discount': 0.0},
        ],
        paid: 15,
      );
      expect(totals.total, 10);
      expect(totals.due, 0);
      expect(totals.recovery, 5);
      expect(totals.delta, -5);
    });

    test('rejects negative or zero quantities', () {
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': -2.0, 'price': 10.0, 'discount': 0.0},
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': 0.0, 'price': 10.0, 'discount': 0.0},
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative price, discount, payment and expenses', () {
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': 1.0, 'price': -1.0, 'discount': 0.0},
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': 1.0, 'price': 10.0, 'discount': -1.0},
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': 1.0, 'price': 10.0, 'discount': 0.0},
          ],
          paid: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': 1.0, 'price': 10.0, 'discount': 0.0},
          ],
          oil: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': 1.0, 'price': 10.0, 'discount': 0.0},
          ],
          other: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects line discount larger than line amount', () {
      expect(
        () => AccountingRules.saleTotals(
          items: [
            {'qty': 1.0, 'price': 10.0, 'discount': 15.0},
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('purchase accounting invariants', () {
    test('calculates supplier due', () {
      final totals = AccountingRules.purchaseTotals(
        items: [
          {'qty': 2.0, 'cost': 25.0},
        ],
        paid: 20,
      );
      expect(totals.total, 50);
      expect(totals.due, 30);
    });

    test('rejects negative cost, negative paid and supplier overpayment', () {
      expect(
        () => AccountingRules.purchaseTotals(
          items: [
            {'qty': 2.0, 'cost': -5.0},
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountingRules.purchaseTotals(
          items: [
            {'qty': 2.0, 'cost': 5.0},
          ],
          paid: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountingRules.purchaseTotals(
          items: [
            {'qty': 2.0, 'cost': 5.0},
          ],
          paid: 11,
        ),
        throwsArgumentError,
      );
    });
  });

  group('debt balance direction', () {
    test('customer/salesman loan and payment deltas are opposite', () {
      expect(AccountingRules.loanBalanceDelta(amount: 20, type: 'loan'), 20);
      expect(AccountingRules.loanBalanceDelta(amount: 20, type: 'payment'), -20);
    });

    test('supplier received/payment deltas are opposite', () {
      expect(AccountingRules.supplierBalanceDelta(amount: 20, type: 'received'), 20);
      expect(AccountingRules.supplierBalanceDelta(amount: 20, type: 'payment'), -20);
    });
  });

  test('stock ledger always starts with opening stock', () {
    final ordered = AccountingRules.orderStockLedgerRows([
      {'date': '2026-10-02', 'type': 'Sale', 'qty': -3.0},
      {'date': 'Opening', 'type': 'Opening Stock', 'qty': 10.0},
      {'date': '2026-10-01', 'type': 'Purchase', 'qty': 5.0},
    ]);

    expect(ordered.map((x) => x['type']), ['Opening Stock', 'Purchase', 'Sale']);

    var running = 0.0;
    final balances = <double>[];
    for (final row in ordered) {
      running += row['qty'] as double;
      balances.add(running);
    }
    expect(balances, [10, 15, 12]);
  });
}
