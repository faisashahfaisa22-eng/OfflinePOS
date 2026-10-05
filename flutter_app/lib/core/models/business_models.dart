class Purchase {
  final int? id;
  final String invoiceNo;
  final int? supplierId;
  final DateTime date;
  final double subtotal, discount, total, paid, due;
  final String notes;

  const Purchase({
    this.id, required this.invoiceNo, this.supplierId, required this.date,
    required this.subtotal, required this.discount, required this.total,
    required this.paid, required this.due, this.notes = '',
  });

  Map<String, Object?> toMap() => {
    'id': id, 'invoice_no': invoiceNo, 'supplier_id': supplierId,
    'date': date.toIso8601String(), 'subtotal': subtotal, 'discount': discount,
    'total': total, 'paid': paid, 'due': due, 'notes': notes,
  };
}

class CashTransaction {
  final int? id;
  final DateTime date;
  final String type, category, reference, description;
  final double amount;
  const CashTransaction({
    this.id, required this.date, required this.type, required this.category,
    this.reference = '', this.description = '', required this.amount,
  });
}

class Loan {
  final int? id;
  final String partyType, partyName, notes;
  final DateTime date;
  final double principal, paid, balance;
  const Loan({
    this.id, required this.partyType, required this.partyName, required this.date,
    required this.principal, required this.paid, required this.balance, this.notes = '',
  });
}
