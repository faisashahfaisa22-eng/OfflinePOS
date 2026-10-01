import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      join(root, 'qamvio_pos.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE business_settings(
            id INTEGER PRIMARY KEY CHECK(id = 1),
            business_name TEXT NOT NULL DEFAULT 'QAMVIO POS',
            business_type TEXT NOT NULL DEFAULT 'general_store',
            currency TEXT NOT NULL DEFAULT 'AFN',
            phone TEXT NOT NULL DEFAULT '',
            address TEXT NOT NULL DEFAULT '',
            invoice_footer TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.insert('business_settings', {'id': 1});

        await db.execute('''
          CREATE TABLE suppliers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            opening_balance REAL NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE purchases(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_no TEXT NOT NULL UNIQUE,
            supplier_id INTEGER,
            date TEXT NOT NULL,
            subtotal REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            paid REAL NOT NULL DEFAULT 0,
            due REAL NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE purchase_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            qty REAL NOT NULL DEFAULT 0,
            unit_cost REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE cash_transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            reference TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            amount REAL NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE loans(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            party_type TEXT NOT NULL,
            party_name TEXT NOT NULL,
            date TEXT NOT NULL,
            principal REAL NOT NULL DEFAULT 0,
            paid REAL NOT NULL DEFAULT 0,
            balance REAL NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT ''
          )
        ''');

        await db.execute('''
          CREATE TABLE fuel_tanks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            fuel_type TEXT NOT NULL,
            capacity REAL NOT NULL DEFAULT 0,
            current_stock REAL NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE fuel_nozzles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tank_id INTEGER,
            name TEXT NOT NULL,
            opening_meter REAL NOT NULL DEFAULT 0,
            current_meter REAL NOT NULL DEFAULT 0,
            price_per_litre REAL NOT NULL DEFAULT 0,
            FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE fuel_sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nozzle_id INTEGER,
            date TEXT NOT NULL,
            opening_meter REAL NOT NULL DEFAULT 0,
            closing_meter REAL NOT NULL DEFAULT 0,
            litres REAL NOT NULL DEFAULT 0,
            price_per_litre REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            cash REAL NOT NULL DEFAULT 0,
            credit REAL NOT NULL DEFAULT 0,
            customer TEXT NOT NULL DEFAULT '',
            salesman TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(nozzle_id) REFERENCES fuel_nozzles(id) ON DELETE SET NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE pharmacy_batches(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medicine_name TEXT NOT NULL,
            batch_no TEXT NOT NULL,
            expiry_date TEXT NOT NULL,
            qty REAL NOT NULL DEFAULT 0,
            purchase_price REAL NOT NULL DEFAULT 0,
            sale_price REAL NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }
}
