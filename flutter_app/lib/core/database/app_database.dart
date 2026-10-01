import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  static const businessTables = <String>[
    'products','customers','suppliers','sales','sale_items','purchases',
    'purchase_items','expenses','salesmen','accounts','account_transactions',
    'loans','loan_payments','fuel_tanks','fuel_nozzles','fuel_shifts',
    'fuel_sales','pharmacy_batches','settings'
  ];

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(join(root, 'qamvio_pos.db'), version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _create(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(db);
      });
  }

  Future<void> _create(Database db) async {
    await db.execute('CREATE TABLE products(id TEXT PRIMARY KEY,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,cost REAL NOT NULL DEFAULT 0,price REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,unit TEXT NOT NULL DEFAULT "pcs",updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE customers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE suppliers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE sales(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL,customer_id TEXT,salesman_id TEXT,subtotal REAL NOT NULL DEFAULT 0,discount REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,payment_method TEXT NOT NULL DEFAULT "cash",created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,cost REAL NOT NULL DEFAULT 0,total REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE purchases(id TEXT PRIMARY KEY,supplier_id TEXT,invoice_no TEXT,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE expenses(id TEXT PRIMARY KEY,name TEXT NOT NULL,category TEXT,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE salesmen(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,commission_rate REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT NOT NULL,type TEXT NOT NULL,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE sync_queue(id INTEGER PRIMARY KEY AUTOINCREMENT,table_name TEXT NOT NULL,record_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0)');
    await _createV2(db);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_created ON sync_queue(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at)');
  }

  Future<void> _createV2(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS purchase_items(id TEXT PRIMARY KEY,purchase_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,cost REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS account_transactions(id TEXT PRIMARY KEY,account_id TEXT NOT NULL,type TEXT NOT NULL,amount REAL NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS loans(id TEXT PRIMARY KEY,party_type TEXT NOT NULL,party_id TEXT,party_name TEXT NOT NULL,principal REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,balance REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS loan_payments(id TEXT PRIMARY KEY,loan_id TEXT NOT NULL,amount REAL NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(loan_id) REFERENCES loans(id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS fuel_tanks(id TEXT PRIMARY KEY,name TEXT NOT NULL,fuel_type TEXT NOT NULL,capacity REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,cost REAL NOT NULL DEFAULT 0,price REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS fuel_nozzles(id TEXT PRIMARY KEY,tank_id TEXT NOT NULL,name TEXT NOT NULL,meter REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS fuel_shifts(id TEXT PRIMARY KEY,salesman_id TEXT,opened_at TEXT NOT NULL,closed_at TEXT,opening_cash REAL NOT NULL DEFAULT 0,closing_cash REAL NOT NULL DEFAULT 0,status TEXT NOT NULL DEFAULT "open",updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS fuel_sales(id TEXT PRIMARY KEY,shift_id TEXT,nozzle_id TEXT,tank_id TEXT,customer_id TEXT,salesman_id TEXT,liters REAL NOT NULL DEFAULT 0,price_per_liter REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS pharmacy_batches(id TEXT PRIMARY KEY,product_id TEXT NOT NULL,batch_no TEXT,expiry_date TEXT,qty REAL NOT NULL DEFAULT 0,cost REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0)');
  }

  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    final out = <String,dynamic>{};
    for (final table in businessTables) {
      out[table] = await db.query(table);
    }
    out['exported_at'] = DateTime.now().toUtc().toIso8601String();
    out['schema_version'] = 2;
    return out;
  }

  Future<void> restoreAll(Map<String,dynamic> payload) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in businessTables.reversed) {
        await txn.delete(table);
      }
      for (final table in businessTables) {
        final rows = payload[table];
        if (rows is! List) continue;
        for (final raw in rows) {
          if (raw is Map) {
            await txn.insert(table, Map<String,Object?>.from(raw), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });
  }

  Future<String> exportJson() async => jsonEncode(await exportAll());
}
