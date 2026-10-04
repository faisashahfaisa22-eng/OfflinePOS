import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class QamvioDatabase {
  QamvioDatabase._();
  static final instance = QamvioDatabase._();
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      join(root, 'qamvio_pos.db'),
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE users (id TEXT PRIMARY KEY, login_id TEXT NOT NULL UNIQUE, role TEXT NOT NULL, password_hash TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE products (id TEXT PRIMARY KEY, name TEXT NOT NULL, sku TEXT, barcode TEXT, category TEXT, cost REAL NOT NULL DEFAULT 0, price REAL NOT NULL DEFAULT 0, stock REAL NOT NULL DEFAULT 0, unit TEXT, expiry_date TEXT, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
        batch.execute('CREATE TABLE customers (id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT, opening_balance REAL NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE suppliers (id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT, opening_balance REAL NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE salesmen (id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, commission_rate REAL NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE sales (id TEXT PRIMARY KEY, invoice_no TEXT NOT NULL UNIQUE, customer_id TEXT, salesman_id TEXT, subtotal REAL NOT NULL DEFAULT 0, discount REAL NOT NULL DEFAULT 0, total REAL NOT NULL DEFAULT 0, paid REAL NOT NULL DEFAULT 0, due REAL NOT NULL DEFAULT 0, sale_date TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL, FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
        batch.execute('CREATE TABLE sale_items (id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT, description TEXT NOT NULL, qty REAL NOT NULL, price REAL NOT NULL, cost REAL NOT NULL DEFAULT 0, total REAL NOT NULL, FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE, FOREIGN KEY(product_id) REFERENCES products(id))');
        batch.execute('CREATE TABLE purchases (id TEXT PRIMARY KEY, supplier_id TEXT, invoice_no TEXT, subtotal REAL NOT NULL DEFAULT 0, discount REAL NOT NULL DEFAULT 0, total REAL NOT NULL DEFAULT 0, paid REAL NOT NULL DEFAULT 0, due REAL NOT NULL DEFAULT 0, purchase_date TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL, FOREIGN KEY(supplier_id) REFERENCES suppliers(id))');
        batch.execute('CREATE TABLE purchase_items (id TEXT PRIMARY KEY, purchase_id TEXT NOT NULL, product_id TEXT, description TEXT NOT NULL, qty REAL NOT NULL, cost REAL NOT NULL, total REAL NOT NULL, FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE, FOREIGN KEY(product_id) REFERENCES products(id))');
        batch.execute('CREATE TABLE expenses (id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT, amount REAL NOT NULL, expense_date TEXT NOT NULL, note TEXT, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE accounts (id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE account_transactions (id TEXT PRIMARY KEY, account_id TEXT NOT NULL, kind TEXT NOT NULL, amount REAL NOT NULL, reference_type TEXT, reference_id TEXT, note TEXT, transaction_date TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY(account_id) REFERENCES accounts(id))');
        batch.execute('CREATE TABLE loans (id TEXT PRIMARY KEY, party_type TEXT NOT NULL, party_id TEXT, amount REAL NOT NULL, paid REAL NOT NULL DEFAULT 0, loan_date TEXT NOT NULL, note TEXT, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE fuel_tanks (id TEXT PRIMARY KEY, name TEXT NOT NULL, fuel_type TEXT NOT NULL, capacity REAL NOT NULL DEFAULT 0, stock REAL NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
        batch.execute('CREATE TABLE fuel_nozzles (id TEXT PRIMARY KEY, tank_id TEXT NOT NULL, name TEXT NOT NULL, meter_reading REAL NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL, FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id))');
        batch.execute('CREATE TABLE fuel_shifts (id TEXT PRIMARY KEY, salesman_id TEXT, opened_at TEXT NOT NULL, closed_at TEXT, cash_total REAL NOT NULL DEFAULT 0, credit_total REAL NOT NULL DEFAULT 0, expense_total REAL NOT NULL DEFAULT 0, updated_at TEXT NOT NULL, FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
        batch.execute('CREATE TABLE fuel_shift_lines (id TEXT PRIMARY KEY, shift_id TEXT NOT NULL, nozzle_id TEXT NOT NULL, opening_meter REAL NOT NULL, closing_meter REAL NOT NULL DEFAULT 0, liters REAL NOT NULL DEFAULT 0, price_per_liter REAL NOT NULL DEFAULT 0, total REAL NOT NULL DEFAULT 0, FOREIGN KEY(shift_id) REFERENCES fuel_shifts(id) ON DELETE CASCADE, FOREIGN KEY(nozzle_id) REFERENCES fuel_nozzles(id))');
        batch.execute('CREATE TABLE sync_queue (id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, synced_at TEXT)');
        await batch.commit(noResult: true);
      },
    );
  }

  Future<Map<String, num>> dashboardTotals() async {
    final db = await database;
    Future<int> count(String table) async => Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE deleted=0')) ?? 0;
    final sales = Sqflite.firstIntValue(await db.rawQuery('SELECT CAST(COALESCE(SUM(total),0) AS INTEGER) FROM sales WHERE deleted=0')) ?? 0;
    final expenses = Sqflite.firstIntValue(await db.rawQuery('SELECT CAST(COALESCE(SUM(amount),0) AS INTEGER) FROM expenses WHERE deleted=0')) ?? 0;
    return {'sales': sales, 'expenses': expenses, 'products': await count('products'), 'customers': await count('customers')};
  }
}
