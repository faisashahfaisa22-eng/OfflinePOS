import '../database/app_database.dart';

class BusinessRepository {
  Future<List<Map<String, Object?>>> purchases() async {
    final db = await AppDatabase.instance.database;
    return db.rawQuery('''
      SELECT p.*, s.name supplier_name
      FROM purchases p LEFT JOIN suppliers s ON s.id=p.supplier_id
      ORDER BY p.date DESC, p.id DESC
    ''');
  }

  Future<int> addPurchase(Map<String, Object?> purchase, List<Map<String, Object?>> items) async {
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final id = await txn.insert('purchases', purchase);
      for (final item in items) {
        await txn.insert('purchase_items', {...item, 'purchase_id': id});
      }
      if ((purchase['paid'] as num? ?? 0) > 0) {
        await txn.insert('cash_transactions', {
          'date': purchase['date'],
          'type': 'out',
          'category': 'purchase',
          'reference': purchase['invoice_no'],
          'description': 'Purchase payment',
          'amount': purchase['paid'],
        });
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> cashLedger() async {
    final db = await AppDatabase.instance.database;
    return db.query('cash_transactions', orderBy: 'date DESC, id DESC');
  }

  Future<double> cashBalance() async {
    final db = await AppDatabase.instance.database;
    final r = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN type='in' THEN amount ELSE -amount END),0) balance
      FROM cash_transactions
    ''');
    return (r.first['balance'] as num? ?? 0).toDouble();
  }

  Future<List<Map<String, Object?>>> loans() async {
    final db = await AppDatabase.instance.database;
    return db.query('loans', orderBy: 'date DESC, id DESC');
  }

  Future<int> addLoan(Map<String, Object?> value) async {
    final db = await AppDatabase.instance.database;
    return db.insert('loans', value);
  }

  Future<Map<String, double>> reportSummary() async {
    final db = await AppDatabase.instance.database;
    final purchase = await db.rawQuery('SELECT COALESCE(SUM(total),0) v FROM purchases');
    final paid = await db.rawQuery('SELECT COALESCE(SUM(paid),0) v FROM purchases');
    final due = await db.rawQuery('SELECT COALESCE(SUM(due),0) v FROM purchases');
    final loan = await db.rawQuery('SELECT COALESCE(SUM(balance),0) v FROM loans');
    return {
      'purchases': (purchase.first['v'] as num? ?? 0).toDouble(),
      'purchasePaid': (paid.first['v'] as num? ?? 0).toDouble(),
      'purchaseDue': (due.first['v'] as num? ?? 0).toDouble(),
      'loanBalance': (loan.first['v'] as num? ?? 0).toDouble(),
      'cash': await cashBalance(),
    };
  }

  Future<List<Map<String, Object?>>> fuelSales() async {
    final db = await AppDatabase.instance.database;
    return db.query('fuel_sales', orderBy: 'date DESC, id DESC');
  }

  Future<int> addFuelSale(Map<String, Object?> value) async {
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final id = await txn.insert('fuel_sales', value);
      final cash = (value['cash'] as num? ?? 0).toDouble();
      if (cash > 0) {
        await txn.insert('cash_transactions', {
          'date': value['date'], 'type': 'in', 'category': 'fuel_sale',
          'reference': 'FUEL-$id', 'description': 'Fuel cash sale', 'amount': cash,
        });
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> medicineBatches() async {
    final db = await AppDatabase.instance.database;
    return db.query('pharmacy_batches', orderBy: 'expiry_date ASC');
  }

  Future<int> addMedicineBatch(Map<String, Object?> value) async {
    final db = await AppDatabase.instance.database;
    return db.insert('pharmacy_batches', value);
  }

  Future<Map<String, Object?>> settings() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('business_settings', where: 'id=1');
    return rows.first;
  }

  Future<void> saveSettings(Map<String, Object?> value) async {
    final db = await AppDatabase.instance.database;
    await db.update('business_settings', value, where: 'id=1');
  }
}
