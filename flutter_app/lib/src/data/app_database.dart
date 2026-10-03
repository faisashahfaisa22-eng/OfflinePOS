import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      join(root, 'qamvio_pos.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final statements = <String>[
          '''CREATE TABLE products(id TEXT PRIMARY KEY,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,cost REAL NOT NULL DEFAULT 0,price REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,unit TEXT NOT NULL DEFAULT 'pcs',active INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
          '''CREATE TABLE customers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
          '''CREATE TABLE suppliers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
          '''CREATE TABLE salesmen(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,active INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
          '''CREATE TABLE sales(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL UNIQUE,customer_id TEXT,salesman_id TEXT,subtotal REAL NOT NULL DEFAULT 0,discount REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,sale_date TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,FOREIGN KEY(customer_id) REFERENCES customers(id),FOREIGN KEY(salesman_id) REFERENCES salesmen(id))''',
          '''CREATE TABLE sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))''',
          '''CREATE TABLE purchases(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL,supplier_id TEXT,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,purchase_date TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))''',
          '''CREATE TABLE expenses(id TEXT PRIMARY KEY,name TEXT NOT NULL,category TEXT,amount REAL NOT NULL,expense_date TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
          '''CREATE TABLE fuel_tanks(id TEXT PRIMARY KEY,name TEXT NOT NULL,fuel_type TEXT NOT NULL,capacity REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
          '''CREATE TABLE fuel_nozzles(id TEXT PRIMARY KEY,tank_id TEXT NOT NULL,name TEXT NOT NULL,meter_reading REAL NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1,FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id))''',
          '''CREATE TABLE app_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL,updated_at TEXT NOT NULL)''',
          '''CREATE TABLE sync_queue(id INTEGER PRIMARY KEY AUTOINCREMENT,entity TEXT NOT NULL,entity_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,synced_at TEXT)'''
        ];
        for (final sql in statements) {
          await db.execute(sql);
        }
      },
    );
  }

  Future<Map<String, num>> dashboardTotals() async {
    final db = await database;
    final sales = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sales')) ?? 0;
    final products = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products WHERE active=1')) ?? 0;
    final customers = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
    final expenseRow = (await db.rawQuery('SELECT COALESCE(SUM(amount),0) AS v FROM expenses')).first;
    return {'sales': sales, 'products': products, 'customers': customers, 'expenses': (expenseRow['v'] as num?) ?? 0};
  }
}
