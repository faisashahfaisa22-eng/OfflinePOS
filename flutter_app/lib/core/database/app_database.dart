import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      join(root, 'qamvio_pos.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE products(id TEXT PRIMARY KEY,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,cost REAL NOT NULL DEFAULT 0,price REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,unit TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE customers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE suppliers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE sales(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL,customer_id TEXT,salesman_id TEXT,subtotal REAL NOT NULL DEFAULT 0,discount REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id))');
        await db.execute('CREATE TABLE sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))');
        await db.execute('CREATE TABLE expenses(id TEXT PRIMARY KEY,name TEXT NOT NULL,category TEXT,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE purchases(id TEXT PRIMARY KEY,supplier_id TEXT,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))');
        await db.execute('CREATE TABLE users(id TEXT PRIMARY KEY,email TEXT,phone TEXT,display_name TEXT,role TEXT NOT NULL DEFAULT "Admin",cloud_user_id TEXT,updated_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT,updated_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE sync_queue(id INTEGER PRIMARY KEY AUTOINCREMENT,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0)');
      },
    );
  }

  Future<Map<String, num>> dashboardTotals() async {
    final db = await database;
    final sales = Sqflite.firstIntValue(await db.rawQuery('SELECT CAST(COALESCE(SUM(total),0) AS INTEGER) FROM sales')) ?? 0;
    final expenses = Sqflite.firstIntValue(await db.rawQuery('SELECT CAST(COALESCE(SUM(amount),0) AS INTEGER) FROM expenses')) ?? 0;
    final products = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    return {'sales': sales, 'expenses': expenses, 'products': products};
  }
}
