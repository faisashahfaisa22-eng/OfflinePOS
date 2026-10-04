class SaleTotals {
  final double subtotal;
  final double lineDiscount;
  final double totalDiscount;
  final double total;
  final double delta;
  final double due;
  final double recovery;

  const SaleTotals({
    required this.subtotal,
    required this.lineDiscount,
    required this.totalDiscount,
    required this.total,
    required this.delta,
    required this.due,
    required this.recovery,
  });
}

class PurchaseTotals {
  final double total;
  final double due;

  const PurchaseTotals({required this.total, required this.due});
}

class AccountingRules {
  AccountingRules._();

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static void _nonNegativeFinite(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, '$name must be a finite value greater than or equal to zero.');
    }
  }

  static SaleTotals saleTotals({
    required List<Map<String, Object?>> items,
    double invoiceDiscount = 0,
    double paid = 0,
    double oil = 0,
    double other = 0,
  }) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Sale must contain at least one item.');
    }
    _nonNegativeFinite(invoiceDiscount, 'invoiceDiscount');
    _nonNegativeFinite(paid, 'paid');
    _nonNegativeFinite(oil, 'oil');
    _nonNegativeFinite(other, 'other');

    var subtotal = 0.0;
    var lineDiscount = 0.0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final qty = _number(item['qty']);
      final price = _number(item['price']);
      final discount = _number(item['discount']);
      if (!qty.isFinite || qty <= 0) {
        throw ArgumentError.value(qty, 'items[$i].qty', 'Sale quantity must be greater than zero.');
      }
      _nonNegativeFinite(price, 'items[$i].price');
      _nonNegativeFinite(discount, 'items[$i].discount');
      final amount = qty * price;
      if (discount > amount) {
        throw ArgumentError.value(
          discount,
          'items[$i].discount',
          'Line discount cannot exceed the line amount.',
        );
      }
      subtotal += amount;
      lineDiscount += discount;
    }

    final netBeforeInvoiceDiscount = subtotal - lineDiscount;
    if (invoiceDiscount > netBeforeInvoiceDiscount) {
      throw ArgumentError.value(
        invoiceDiscount,
        'invoiceDiscount',
        'Invoice discount cannot exceed the remaining invoice amount.',
      );
    }

    final totalDiscount = lineDiscount + invoiceDiscount;
    final total = subtotal - totalDiscount;
    final delta = total - paid;
    return SaleTotals(
      subtotal: subtotal,
      lineDiscount: lineDiscount,
      totalDiscount: totalDiscount,
      total: total,
      delta: delta,
      due: delta > 0 ? delta : 0,
      recovery: delta < 0 ? -delta : 0,
    );
  }

  static PurchaseTotals purchaseTotals({
    required List<Map<String, Object?>> items,
    double paid = 0,
  }) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Purchase must contain at least one item.');
    }
    _nonNegativeFinite(paid, 'paid');

    var total = 0.0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final qty = _number(item['qty']);
      final cost = _number(item['cost']);
      if (!qty.isFinite || qty <= 0) {
        throw ArgumentError.value(qty, 'items[$i].qty', 'Purchase quantity must be greater than zero.');
      }
      _nonNegativeFinite(cost, 'items[$i].cost');
      total += qty * cost;
    }
    if (paid > total) {
      throw ArgumentError.value(
        paid,
        'paid',
        'Paid amount cannot exceed purchase total because supplier prepayment is not modeled.',
      );
    }
    return PurchaseTotals(total: total, due: total - paid);
  }

  static double loanBalanceDelta({required double amount, required String type}) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be greater than zero.');
    }
    if (type == 'loan') return amount;
    if (type == 'payment') return -amount;
    throw ArgumentError.value(type, 'type', 'Use loan or payment.');
  }

  static double supplierBalanceDelta({required double amount, required String type}) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be greater than zero.');
    }
    if (type == 'received') return amount;
    if (type == 'payment') return -amount;
    throw ArgumentError.value(type, 'type', 'Use payment or received.');
  }

  static List<Map<String, Object?>> orderStockLedgerRows(
    List<Map<String, Object?>> rows,
  ) {
    final ordered = rows.map(Map<String, Object?>.from).toList();
    ordered.sort((a, b) {
      final aOpening = a['type'] == 'Opening Stock';
      final bOpening = b['type'] == 'Opening Stock';
      if (aOpening != bOpening) return aOpening ? -1 : 1;
      return (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? '');
    });
    return ordered;
  }
}
