import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(join(root, 'qamvio_pos.db'), version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE products(id TEXT PRIMARY KEY,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,cost REAL NOT NULL DEFAULT 0,price REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,unit TEXT NOT NULL DEFAULT "pcs",updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE customers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE suppliers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE sales(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL,customer_id TEXT,salesman_id TEXT,subtotal REAL NOT NULL DEFAULT 0,discount REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,cost REAL NOT NULL DEFAULT 0,total REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE)');
        await db.execute('CREATE TABLE purchases(id TEXT PRIMARY KEY,supplier_id TEXT,invoice_no TEXT,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE expenses(id TEXT PRIMARY KEY,name TEXT NOT NULL,category TEXT,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE salesmen(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,commission_rate REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT NOT NULL,type TEXT NOT NULL,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL,updated_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE sync_queue(id INTEGER PRIMARY KEY AUTOINCREMENT,table_name TEXT NOT NULL,record_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE INDEX idx_sync_queue_created ON sync_queue(created_at)');
        await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
      });
  }
}
