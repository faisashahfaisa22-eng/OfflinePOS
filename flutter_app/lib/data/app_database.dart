import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      join(root, 'qamvio_pos.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
    );
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''CREATE TABLE products(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, sku TEXT, barcode TEXT,
      cost REAL NOT NULL DEFAULT 0, price REAL NOT NULL DEFAULT 0,
      stock REAL NOT NULL DEFAULT 0, category TEXT, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE customers(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
      balance REAL NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE suppliers(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
      balance REAL NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE sales(
      id TEXT PRIMARY KEY, invoice_no TEXT NOT NULL, customer_id TEXT,
      salesman_id TEXT, subtotal REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0, paid REAL NOT NULL DEFAULT 0,
      total REAL NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE sale_items(
      id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT,
      product_name TEXT NOT NULL, qty REAL NOT NULL, price REAL NOT NULL,
      total REAL NOT NULL, FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE purchases(
      id TEXT PRIMARY KEY, supplier_id TEXT, total REAL NOT NULL DEFAULT 0,
      paid REAL NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE expenses(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, amount REAL NOT NULL DEFAULT 0,
      note TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE salesmen(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, active INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE app_settings(
      key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE sync_queue(
      id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL,
      entity_id TEXT NOT NULL, operation TEXT NOT NULL,
      payload TEXT NOT NULL, created_at TEXT NOT NULL, synced INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE fuel_tanks(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, fuel_type TEXT NOT NULL,
      capacity REAL NOT NULL DEFAULT 0, current_stock REAL NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE fuel_nozzles(
      id TEXT PRIMARY KEY, tank_id TEXT NOT NULL, name TEXT NOT NULL,
      meter_reading REAL NOT NULL DEFAULT 0, updated_at TEXT NOT NULL,
      FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id))''');
  }

  Future<List<Map<String, Object?>>> listProducts() async {
    final db = await database;
    return db.query('products', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveProduct({
    required String name,
    String sku = '',
    double cost = 0,
    double price = 0,
    double stock = 0,
  }) async {
    final db = await database;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final row = <String, Object?>{
        'id': id,
        'name': name,
        'sku': sku,
        'barcode': sku,
        'cost': cost,
        'price': price,
        'stock': stock,
        'category': '',
        'updated_at': now,
      };
      await txn.insert('products', row);
      await txn.insert('sync_queue', {
        'entity': 'products',
        'entity_id': id,
        'operation': 'upsert',
        'payload': row.toString(),
        'created_at': now,
        'synced': 0,
      });
    });
  }
}
