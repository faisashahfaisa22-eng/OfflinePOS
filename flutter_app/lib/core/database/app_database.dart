import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../security/crypto_utils.dart';
import 'sarafi_repository.dart';

/// SQLCipher-encrypted database. It can only be opened after the user signs in
/// (see LocalAuthService), because the key is the user's unwrapped data key.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
  String? _keyHex;

  bool get isUnlocked=>_keyHex!=null;

  Future<void> unlock(List<int> dek) async {
    final hex=CryptoUtils.toHex(dek);
    if(_keyHex!=hex) {
      await _db?.close();
      _db=null;
    }
    _keyHex=hex;
  }

  Future<void> lock() async {
    final db=_db;
    _db=null;
    _keyHex=null;
    await db?.close();
  }

  /// Deletes the on-disk database. Only used to roll back a failed
  /// fresh-install restore, before any real data exists on the device.
  Future<void> deleteFile() async {
    await lock();
    final root=await getDatabasesPath();
    final path=join(root,'qamvio_pos.db');
    for(final suffix in const ['','-wal','-shm','-journal']) {
      final f=File('$path$suffix');
      if(await f.exists()) await f.delete();
    }
  }

  Future<Database> get database async {
    if(_keyHex==null) throw StateError('Database is locked. Sign in first.');
    return _db ??= await _open();
  }

  String get _sqlcipherKey=>"x'${_keyHex!}'";

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    final path = join(root, 'qamvio_pos.db');
    await _recoverInterruptedPlainMigration(path);
    await _encryptLegacyPlainDatabaseIfNeeded(path);
    return openDatabase(
      path,
      password: _sqlcipherKey,
      version: 8,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createSchema(db);
        await SarafiSchema.create(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2Tables(db);
        if (oldVersion < 3) await _createV3Tables(db);
        if (oldVersion < 4) await _createV4Tables(db);
        if (oldVersion < 5) await _createV5Tables(db);
        if (oldVersion < 6) await _createV6Tables(db);
        if (oldVersion < 7) await _createV7Tables(db);
        if (oldVersion < 8) await SarafiSchema.create(db);
      },
    );
  }

  Future<bool> _isPlainSqlite(String path) async {
    final f=File(path);
    if(!await f.exists()) return false;
    final raf=await f.open();
    try {
      final head=await raf.read(16);
      return String.fromCharCodes(head).startsWith('SQLite format 3');
    } finally {
      await raf.close();
    }
  }

  Future<void> _verifyEncryptedDatabase(String path) async {
    final check=await openDatabase(path,password:_sqlcipherKey,readOnly:true);
    try {
      final tables=Sqflite.firstIntValue(
        await check.rawQuery("SELECT COUNT(*) FROM sqlite_master WHERE type='table'"),
      )??0;
      if(tables==0) {
        throw StateError('Encrypted database verification found no tables.');
      }
      final integrity=await check.rawQuery('PRAGMA integrity_check');
      final result=integrity.isEmpty ? '' : integrity.first.values.first?.toString()??'';
      if(result.toLowerCase()!='ok') {
        throw StateError('Encrypted database integrity check failed: $result');
      }
    } finally {
      await check.close();
    }
  }

  Future<void> _deleteSidecars(String base,{bool includeMain=false}) async {
    final suffixes=includeMain
      ?const ['','-wal','-shm','-journal']
      :const ['-wal','-shm','-journal'];
    for(final suffix in suffixes) {
      final f=File('$base$suffix');
      if(await f.exists()) await f.delete();
    }
  }

  /// Repairs the only crash-sensitive window in the plaintext -> SQLCipher swap.
  /// If the app stopped after moving the plaintext DB aside, the next launch
  /// restores it instead of silently creating a new empty database.
  Future<void> _recoverInterruptedPlainMigration(String path) async {
    final backup='$path.plain.bak';
    final main=File(path);
    final old=File(backup);
    if(!await old.exists()) return;

    if(!await main.exists()) {
      await old.rename(path);
      return;
    }

    if(await _isPlainSqlite(path)) {
      // The normal plaintext database is already back in place.
      await _deleteSidecars(backup,includeMain:true);
      return;
    }

    try {
      await _verifyEncryptedDatabase(path);
      // Encrypted replacement is valid; the old plaintext copy can now go.
      await _deleteSidecars(backup,includeMain:true);
    } catch(_) {
      // Replacement is unusable. Restore the untouched plaintext backup.
      await _deleteSidecars(path,includeMain:true);
      await old.rename(path);
    }
  }

  /// Earlier Flutter builds stored the business data unencrypted. On first
  /// unlock it is copied into an encrypted file (sqlcipher_export), verified,
  /// and then swapped into place with a rollback copy kept until final verify.
  Future<void> _encryptLegacyPlainDatabaseIfNeeded(String path) async {
    if(!await _isPlainSqlite(path)) return;
    final tmp='$path.enc';
    final backup='$path.plain.bak';
    await _deleteSidecars(tmp,includeMain:true);
    await _deleteSidecars(backup,includeMain:true);

    final plain=await openDatabase(path);
    int version;
    try {
      version=Sqflite.firstIntValue(await plain.rawQuery('PRAGMA user_version'))??0;
      final safeTmp=tmp.replaceAll("'","''");
      await plain.execute("ATTACH DATABASE '$safeTmp' AS encrypted KEY \"$_sqlcipherKey\"");
      await plain.rawQuery("SELECT sqlcipher_export('encrypted')");
      await plain.execute('PRAGMA encrypted.user_version = $version');
      await plain.execute('DETACH DATABASE encrypted');
      // Make the main file self-contained before it becomes our rollback copy.
      try {
        await plain.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } catch(_) {
        // Not every journal mode supports/needs a WAL checkpoint.
      }
    } finally {
      await plain.close();
    }

    // Verify the encrypted copy before touching the original.
    await _verifyEncryptedDatabase(tmp);

    // Old WAL/SHM data must never be left beside the new encrypted main file.
    await _deleteSidecars(path);

    final original=File(path);
    await original.rename(backup);
    try {
      await File(tmp).rename(path);
      // Verify again at the final path before deleting the plaintext rollback.
      await _verifyEncryptedDatabase(path);
      await _deleteSidecars(backup,includeMain:true);
    } catch(e) {
      await _deleteSidecars(path,includeMain:true);
      final rollback=File(backup);
      if(await rollback.exists()) await rollback.rename(path);
      rethrow;
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('CREATE TABLE products(id TEXT PRIMARY KEY,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,cost REAL NOT NULL DEFAULT 0,price REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,opening_qty REAL NOT NULL DEFAULT 0,reorder_level REAL NOT NULL DEFAULT 0,unit TEXT,batch_no TEXT,expiry_date TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE customers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,salesman_id TEXT,opening REAL NOT NULL DEFAULT 0,credit_limit REAL NOT NULL DEFAULT 0,note TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
    await db.execute('CREATE TABLE suppliers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,opening REAL NOT NULL DEFAULT 0,note TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE salesmen(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,commission REAL NOT NULL DEFAULT 0,credit_limit REAL NOT NULL DEFAULT 0,note TEXT,active INTEGER NOT NULL DEFAULT 1,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE sales(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL,business_date TEXT,vehicle TEXT,customer_id TEXT,salesman_id TEXT,subtotal REAL NOT NULL DEFAULT 0,discount REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,recovery REAL NOT NULL DEFAULT 0,oil REAL NOT NULL DEFAULT 0,other REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id),FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
    await db.execute('CREATE TABLE sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,discount REAL NOT NULL DEFAULT 0,cost REAL,total REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE expenses(id TEXT PRIMARY KEY,business_date TEXT,name TEXT NOT NULL,category TEXT,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE purchases(id TEXT PRIMARY KEY,business_date TEXT,invoice_no TEXT,note TEXT,source TEXT,fuel_tank_id TEXT,supplier_id TEXT,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id),FOREIGN KEY(fuel_tank_id) REFERENCES fuel_tanks(id))');
    await db.execute('CREATE TABLE purchase_items(id TEXT PRIMARY KEY,purchase_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,cost REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE customer_loans(id TEXT PRIMARY KEY,business_date TEXT,customer_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id))');
    await db.execute('CREATE TABLE salesman_loans(id TEXT PRIMARY KEY,business_date TEXT,salesman_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,source TEXT,linked_sale_id TEXT,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(salesman_id) REFERENCES salesmen(id),FOREIGN KEY(linked_sale_id) REFERENCES sales(id) ON DELETE SET NULL)');
    await db.execute('CREATE TABLE supplier_transactions(id TEXT PRIMARY KEY,business_date TEXT,supplier_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))');
    await db.execute('CREATE TABLE fuel_tanks(id TEXT PRIMARY KEY,name TEXT NOT NULL,product_id TEXT,fuel_type TEXT NOT NULL,capacity REAL NOT NULL DEFAULT 0,opening_liters REAL NOT NULL DEFAULT 0,current_stock REAL NOT NULL DEFAULT 0,note TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE fuel_nozzles(id TEXT PRIMARY KEY,tank_id TEXT NOT NULL,name TEXT NOT NULL,opening_meter REAL NOT NULL DEFAULT 0,meter_reading REAL NOT NULL DEFAULT 0,price_per_unit REAL NOT NULL DEFAULT 0,note TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id))');
    await db.execute('CREATE TABLE fuel_shifts(id TEXT PRIMARY KEY,business_date TEXT,tank_id TEXT,nozzle_id TEXT NOT NULL,salesman_id TEXT,customer_id TEXT,sale_id TEXT,shift_name TEXT,invoice_no TEXT,opening_meter REAL NOT NULL DEFAULT 0,closing_meter REAL,litres REAL NOT NULL DEFAULT 0,price_per_unit REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,cash_received REAL NOT NULL DEFAULT 0,expense REAL NOT NULL DEFAULT 0,started_at TEXT NOT NULL,closed_at TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id),FOREIGN KEY(nozzle_id) REFERENCES fuel_nozzles(id),FOREIGN KEY(salesman_id) REFERENCES salesmen(id),FOREIGN KEY(customer_id) REFERENCES customers(id),FOREIGN KEY(sale_id) REFERENCES sales(id))');
    await db.execute('CREATE TABLE users(id TEXT PRIMARY KEY,email TEXT,phone TEXT,display_name TEXT,role TEXT NOT NULL DEFAULT "Admin",cloud_user_id TEXT,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE sync_queue(id INTEGER PRIMARY KEY AUTOINCREMENT,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE legacy_archives(id INTEGER PRIMARY KEY AUTOINCREMENT,source TEXT NOT NULL,source_updated_at TEXT,archived_at TEXT NOT NULL,status TEXT NOT NULL,payload TEXT NOT NULL)');
    await db.execute('CREATE TABLE migration_state(key TEXT PRIMARY KEY,value TEXT,updated_at TEXT NOT NULL)');
    await _createV6Tables(db);
  }

  Future<void> _createV2Tables(Database db) async {
    final statements = <String>[
      'CREATE TABLE IF NOT EXISTS salesmen(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,commission REAL NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)',
      'CREATE TABLE IF NOT EXISTS purchase_items(id TEXT PRIMARY KEY,purchase_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,cost REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))',
      'CREATE TABLE IF NOT EXISTS customer_loans(id TEXT PRIMARY KEY,customer_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id))',
      'CREATE TABLE IF NOT EXISTS supplier_transactions(id TEXT PRIMARY KEY,supplier_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))',
      'CREATE TABLE IF NOT EXISTS fuel_tanks(id TEXT PRIMARY KEY,name TEXT NOT NULL,fuel_type TEXT NOT NULL,capacity REAL NOT NULL DEFAULT 0,current_stock REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)',
      'CREATE TABLE IF NOT EXISTS fuel_nozzles(id TEXT PRIMARY KEY,tank_id TEXT NOT NULL,name TEXT NOT NULL,meter_reading REAL NOT NULL DEFAULT 0,price_per_unit REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id))',
      'CREATE TABLE IF NOT EXISTS fuel_shifts(id TEXT PRIMARY KEY,nozzle_id TEXT NOT NULL,salesman_id TEXT,opening_meter REAL NOT NULL DEFAULT 0,closing_meter REAL,litres REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,cash_received REAL NOT NULL DEFAULT 0,expense REAL NOT NULL DEFAULT 0,started_at TEXT NOT NULL,closed_at TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(nozzle_id) REFERENCES fuel_nozzles(id))',
    ];
    for (final sql in statements) { await db.execute(sql); }
  }

  Future<void> _createV3Tables(Database db) async {
    final cols=await db.rawQuery("PRAGMA table_info(products)");
    final names=cols.map((x)=>x['name']?.toString()).toSet();
    if(!names.contains('batch_no')) await db.execute('ALTER TABLE products ADD COLUMN batch_no TEXT');
    if(!names.contains('expiry_date')) await db.execute('ALTER TABLE products ADD COLUMN expiry_date TEXT');
  }


  Future<void> _createV4Tables(Database db) async {
    final itemCols=await db.rawQuery("PRAGMA table_info(sale_items)");
    final itemNames=itemCols.map((x)=>x['name']?.toString()).toSet();
    if(!itemNames.contains('cost')) {
      await db.execute('ALTER TABLE sale_items ADD COLUMN cost REAL');
    }
    await db.execute('CREATE TABLE IF NOT EXISTS legacy_archives(id INTEGER PRIMARY KEY AUTOINCREMENT,source TEXT NOT NULL,source_updated_at TEXT,archived_at TEXT NOT NULL,status TEXT NOT NULL,payload TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS migration_state(key TEXT PRIMARY KEY,value TEXT,updated_at TEXT NOT NULL)');
  }

  Future<void> _createV5Tables(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS salesman_loans(id TEXT PRIMARY KEY,salesman_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,source TEXT,linked_sale_id TEXT,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(salesman_id) REFERENCES salesmen(id),FOREIGN KEY(linked_sale_id) REFERENCES sales(id) ON DELETE SET NULL)');
  }

  Future<void> _createV6Tables(Database db) async {
    Future<void> addColumn(String table,String name,String definition) async {
      final cols=await db.rawQuery('PRAGMA table_info('+table+')');
      final names=cols.map((x)=>x['name']?.toString()).toSet();
      if(!names.contains(name)) {
        await db.execute('ALTER TABLE '+table+' ADD COLUMN '+name+' '+definition);
      }
    }

    await addColumn('products','opening_qty','REAL NOT NULL DEFAULT 0');
    await addColumn('products','reorder_level','REAL NOT NULL DEFAULT 0');
    await addColumn('customers','salesman_id','TEXT');
    await addColumn('customers','opening','REAL NOT NULL DEFAULT 0');
    await addColumn('customers','credit_limit','REAL NOT NULL DEFAULT 0');
    await addColumn('customers','note','TEXT');
    await addColumn('suppliers','opening','REAL NOT NULL DEFAULT 0');
    await addColumn('suppliers','note','TEXT');
    await addColumn('salesmen','credit_limit','REAL NOT NULL DEFAULT 0');
    await addColumn('salesmen','note','TEXT');
    await addColumn('sales','business_date','TEXT');
    await addColumn('sales','vehicle','TEXT');
    await addColumn('sales','recovery','REAL NOT NULL DEFAULT 0');
    await addColumn('sales','oil','REAL NOT NULL DEFAULT 0');
    await addColumn('sales','other','REAL NOT NULL DEFAULT 0');
    await addColumn('sales','note','TEXT');
    await addColumn('sale_items','discount','REAL NOT NULL DEFAULT 0');
    await addColumn('purchases','business_date','TEXT');
    await addColumn('purchases','invoice_no','TEXT');
    await addColumn('purchases','note','TEXT');
    await addColumn('purchases','source','TEXT');
    await addColumn('purchases','fuel_tank_id','TEXT');
    await addColumn('fuel_tanks','product_id','TEXT');
    await addColumn('fuel_tanks','opening_liters','REAL NOT NULL DEFAULT 0');
    await addColumn('fuel_tanks','note','TEXT');
    await addColumn('fuel_nozzles','opening_meter','REAL NOT NULL DEFAULT 0');
    await addColumn('fuel_nozzles','note','TEXT');
    await addColumn('fuel_shifts','business_date','TEXT');
    await addColumn('fuel_shifts','tank_id','TEXT');
    await addColumn('fuel_shifts','customer_id','TEXT');
    await addColumn('fuel_shifts','sale_id','TEXT');
    await addColumn('fuel_shifts','shift_name','TEXT');
    await addColumn('fuel_shifts','invoice_no','TEXT');
    await addColumn('fuel_shifts','price_per_unit','REAL NOT NULL DEFAULT 0');

    await db.execute('CREATE TABLE IF NOT EXISTS capital(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,name TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS stock_adjustments(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,product_id TEXT NOT NULL,qty REAL NOT NULL DEFAULT 0,note TEXT,source TEXT,fuel_tank_id TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(product_id) REFERENCES products(id),FOREIGN KEY(fuel_tank_id) REFERENCES fuel_tanks(id))');
    await db.execute('CREATE TABLE IF NOT EXISTS fuel_closings(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,opening_cash REAL NOT NULL DEFAULT 0,cash_in REAL NOT NULL DEFAULT 0,cash_out REAL NOT NULL DEFAULT 0,expected_cash REAL NOT NULL DEFAULT 0,actual_cash REAL NOT NULL DEFAULT 0,variance REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS recycle_bin(id TEXT PRIMARY KEY,section TEXT NOT NULL,label TEXT,record_json TEXT NOT NULL,linked_records_json TEXT,deleted_at TEXT NOT NULL)');
  }

  Future<void> _createV7Tables(Database db) async {
    Future<void> addColumn(String table,String name,String definition) async {
      final cols=await db.rawQuery('PRAGMA table_info('+table+')');
      final names=cols.map((x)=>x['name']?.toString()).toSet();
      if(!names.contains(name)) {
        await db.execute('ALTER TABLE '+table+' ADD COLUMN '+name+' '+definition);
      }
    }
    await addColumn('expenses','business_date','TEXT');
    await addColumn('customer_loans','business_date','TEXT');
    await addColumn('salesman_loans','business_date','TEXT');
    await addColumn('supplier_transactions','business_date','TEXT');
  }

  Future<List<Map<String, Object?>>> products() async {
    final db = await database;
    return db.query('products', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveProduct({
    required String id,
    required String name,
    String? barcode,
    String? category,
    double cost=0,
    double price=0,
    double stock=0,
    double? openingQty,
    double reorderLevel=0,
    String unit='pcs',
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('products', {
      'id': id, 'name': name.trim(), 'barcode': barcode, 'category': category,
      'cost':cost,
      'price':price,
      'stock':stock,
      'opening_qty':openingQty??stock,
      'reorder_level':reorderLevel,
      'unit':unit,
      'updated_at':now,
      'sync_state':0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }


  Future<List<Map<String, Object?>>> customers() async {
    final db = await database;
    return db.query('customers', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveCustomer({
    required String id,
    required String name,
    String? phone,
    String? address,
    String? salesmanId,
    double opening=0,
    double creditLimit=0,
    String? note,
  }) async {
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    final existing=await db.query(
      'customers',
      columns:['opening','balance'],
      where:'id=?',
      whereArgs:[id],
      limit:1,
    );
    final balance=existing.isEmpty
      ?opening
      :_nDb(existing.first['balance'])+(opening-_nDb(existing.first['opening']));
    await db.insert('customers',{
      'id':id,
      'name':name.trim(),
      'phone':phone,
      'address':address,
      'salesman_id':salesmanId,
      'opening':opening,
      'credit_limit':creditLimit,
      'note':note,
      'balance':balance,
      'updated_at':now,
      'sync_state':0,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> suppliers() async {
    final db = await database;
    return db.query('suppliers', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveSupplier({
    required String id,
    required String name,
    String? phone,
    String? address,
    double opening=0,
    String? note,
  }) async {
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    final existing=await db.query(
      'suppliers',
      columns:['opening','balance'],
      where:'id=?',
      whereArgs:[id],
      limit:1,
    );
    final balance=existing.isEmpty
      ?opening
      :_nDb(existing.first['balance'])+(opening-_nDb(existing.first['opening']));
    await db.insert('suppliers',{
      'id':id,
      'name':name.trim(),
      'phone':phone,
      'address':address,
      'opening':opening,
      'note':note,
      'balance':balance,
      'updated_at':now,
      'sync_state':0,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<List<Map<String,Object?>>> salesmen() async {
    final db=await database;
    return db.query('salesmen',orderBy:'name COLLATE NOCASE');
  }

  Future<void> saveSalesman({
    required String id,
    required String name,
    String? phone,
    double commission=0,
    double creditLimit=0,
    String? note,
    bool active=true,
  }) async {
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    await db.insert('salesmen',{
      'id':id,
      'name':name.trim(),
      'phone':phone?.trim(),
      'commission':commission,
      'credit_limit':creditLimit,
      'note':note,
      'active':active?1:0,
      'updated_at':now,
      'sync_state':0,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> expenses() async {
    final db = await database;
    return db.query('expenses', orderBy: 'created_at DESC');
  }

  Future<void> saveExpense({
    required String id,
    required String name,
    String? category,
    required double amount,
    String? note,
    DateTime? businessDate,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('expenses', {
      'id':id,
      'business_date':(businessDate??DateTime.now()).toIso8601String().split('T').first,
      'name':name.trim(),
      'category':category,
      'amount':amount,
      'note':note,
      'created_at':now,
      'updated_at':now,
      'sync_state':0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> sales() async {
    final db = await database;
    return db.query('sales', orderBy: 'created_at DESC');
  }

  Future<void> createSale({
    required String id,
    required String invoiceNo,
    String? customerId,
    String? salesmanId,
    String? vehicle,
    required List<Map<String,Object?>> items,
    double discount=0,
    double paid=0,
    double oil=0,
    double other=0,
    String? note,
    DateTime? businessDate,
  }) async {
    final db=await database;
    await db.transaction((txn) async {
      final now=DateTime.now().toUtc().toIso8601String();

      // v15 edit semantics: reverse the existing invoice first, then write the
      // edited invoice with the same ID inside this one transaction.
      final existing=await txn.query('sales',where:'id=?',whereArgs:[id],limit:1);
      if(existing.isNotEmpty) {
        final old=existing.first;
        final oldItems=await txn.query('sale_items',where:'sale_id=?',whereArgs:[id]);
        for(final item in oldItems) {
          final pid=item['product_id']?.toString();
          if(pid!=null&&pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock=stock+?,updated_at=?,sync_state=0 WHERE id=?',
              [_nDb(item['qty']),now,pid],
            );
          }
        }
        final oldCustomer=old['customer_id']?.toString();
        if(oldCustomer!=null&&oldCustomer.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE customers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(old['total'])-_nDb(old['paid']),now,oldCustomer],
          );
        }
        await txn.delete('salesman_loans',where:'linked_sale_id=?',whereArgs:[id]);
        await txn.delete('sale_items',where:'sale_id=?',whereArgs:[id]);
        await txn.delete('sales',where:'id=?',whereArgs:[id]);
      }

      final day=(businessDate??DateTime.now()).toIso8601String().split('T').first;
      double subtotal=0;
      double lineDiscount=0;
      for(final item in items) {
        final qty=(item['qty'] as num?)?.toDouble()??0;
        final price=(item['price'] as num?)?.toDouble()??0;
        final disc=(item['discount'] as num?)?.toDouble()??0;
        subtotal+=qty*price;
        lineDiscount+=disc;
      }
      final totalDiscount=(lineDiscount+discount).clamp(0,double.infinity).toDouble();
      final total=(subtotal-totalDiscount).clamp(0,double.infinity).toDouble();
      final delta=total-paid;
      final due=delta>0?delta:0.0;
      final recovery=delta<0?-delta:0.0;

      await txn.insert('sales',{
        'id':id,
        'invoice_no':invoiceNo,
        'business_date':day,
        'vehicle':vehicle?.trim(),
        'customer_id':customerId,
        'salesman_id':salesmanId,
        'subtotal':subtotal,
        'discount':totalDiscount,
        'total':total,
        'paid':paid,
        'due':due,
        'recovery':recovery,
        'oil':oil,
        'other':other,
        'note':note,
        'created_at':now,
        'updated_at':now,
        'sync_state':0,
      });

      if(customerId!=null&&customerId.isNotEmpty&&delta!=0) {
        await txn.rawUpdate(
          'UPDATE customers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
          [delta,now,customerId],
        );
      }

      for(var i=0;i<items.length;i++) {
        final item=items[i];
        final qty=(item['qty'] as num?)?.toDouble()??0;
        final price=(item['price'] as num?)?.toDouble()??0;
        final disc=(item['discount'] as num?)?.toDouble()??0;
        final productId=item['product_id'] as String?;
        await txn.insert('sale_items',{
          'id':'${id}_$i',
          'sale_id':id,
          'product_id':productId,
          'product_name':item['product_name'],
          'qty':qty,
          'price':price,
          'discount':disc,
          'cost':(item['cost'] as num?)?.toDouble(),
          'total':(qty*price-disc).clamp(0,double.infinity).toDouble(),
        });
        if(productId!=null) {
          await txn.rawUpdate(
            'UPDATE products SET stock=stock-?,updated_at=?,sync_state=0 WHERE id=?',
            [qty,now,productId],
          );
        }
      }

      if((customerId==null||customerId.isEmpty)&&
         salesmanId!=null&&salesmanId.isNotEmpty) {
        if(due>0) {
          await txn.insert('salesman_loans',{
            'id':'${id}_sale_due',
            'business_date':day,
            'salesman_id':salesmanId,
            'amount':due,
            'type':'loan',
            'source':'sale_due',
            'linked_sale_id':id,
            'note':'Automatic invoice due / Invoice $invoiceNo',
            'created_at':day+'T00:00:00.000Z',
            'updated_at':now,
            'sync_state':0,
          });
        }
        if(recovery>0) {
          await txn.insert('salesman_loans',{
            'id':'${id}_sale_recovery',
            'business_date':day,
            'salesman_id':salesmanId,
            'amount':recovery,
            'type':'payment',
            'source':'sale_recovery',
            'linked_sale_id':id,
            'note':'Automatic invoice recovery / Invoice $invoiceNo',
            'created_at':day+'T00:00:00.000Z',
            'updated_at':now,
            'sync_state':0,
          });
        }
      }
    });
  }

  Future<void> createPurchase({
    required String id,
    required String supplierId,
    required List<Map<String,Object?>> items,
    double paid=0,
    String? invoiceNo,
    String? note,
    String? source,
    String? fuelTankId,
    DateTime? businessDate,
  }) async {
    final db=await database;
    await db.transaction((txn) async {
      final now=DateTime.now().toUtc().toIso8601String();

      final existing=await txn.query('purchases',where:'id=?',whereArgs:[id],limit:1);
      if(existing.isNotEmpty) {
        final old=existing.first;
        final oldItems=await txn.query('purchase_items',where:'purchase_id=?',whereArgs:[id]);
        for(final item in oldItems) {
          final pid=item['product_id']?.toString();
          if(pid!=null&&pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock=stock-?,updated_at=?,sync_state=0 WHERE id=?',
              [_nDb(item['qty']),now,pid],
            );
          }
        }
        final oldSupplier=old['supplier_id']?.toString();
        if(oldSupplier!=null&&oldSupplier.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE suppliers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(old['due']),now,oldSupplier],
          );
        }
        await txn.delete('purchase_items',where:'purchase_id=?',whereArgs:[id]);
        await txn.delete('purchases',where:'id=?',whereArgs:[id]);
      }

      final day=(businessDate??DateTime.now()).toIso8601String().split('T').first;
      double total=0;
      for(final item in items) {
        final qty=(item['qty'] as num?)?.toDouble()??0;
        final cost=(item['cost'] as num?)?.toDouble()??0;
        total+=qty*cost;
      }
      final due=(total-paid).clamp(0,double.infinity).toDouble();
      await txn.insert('purchases',{
        'id':id,
        'business_date':day,
        'invoice_no':invoiceNo,
        'note':note,
        'source':source,
        'fuel_tank_id':fuelTankId,
        'supplier_id':supplierId,
        'total':total,
        'paid':paid,
        'due':due,
        'created_at':now,
        'updated_at':now,
        'sync_state':0,
      });
      for(var i=0;i<items.length;i++) {
        final item=items[i];
        final productId=item['product_id']?.toString();
        final qty=(item['qty'] as num?)?.toDouble()??0;
        final cost=(item['cost'] as num?)?.toDouble()??0;
        final p=await txn.query(
          'products',
          columns:['name'],
          where:'id=?',
          whereArgs:[productId],
          limit:1,
        );
        await txn.insert('purchase_items',{
          'id':'${id}_$i',
          'purchase_id':id,
          'product_id':productId,
          'product_name':p.isEmpty?'Product':p.first['name'],
          'qty':qty,
          'cost':cost,
          'total':qty*cost,
        });
        await txn.rawUpdate(
          'UPDATE products SET stock=stock+?,cost=?,updated_at=?,sync_state=0 WHERE id=?',
          [qty,cost,now,productId],
        );
      }
      await txn.rawUpdate(
        'UPDATE suppliers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
        [due,now,supplierId],
      );
    });
  }

  Future<void> saveCustomerLoan({
    required String id,
    required String customerId,
    required double amount,
    required String type,
    String? note,
    DateTime? businessDate,
  }) async {
    if(amount<=0) throw ArgumentError.value(amount,'amount','Amount must be greater than zero.');
    if(type!='loan'&&type!='payment') throw ArgumentError.value(type,'type','Use loan or payment.');
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final old=await txn.query('customer_loans',where:'id=?',whereArgs:[id],limit:1);
      if(old.isNotEmpty) {
        final o=old.first;
        final oldDelta=o['type']=='payment'?-_nDb(o['amount']):_nDb(o['amount']);
        await txn.rawUpdate(
          'UPDATE customers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
          [oldDelta,now,o['customer_id']],
        );
        await txn.delete('customer_loans',where:'id=?',whereArgs:[id]);
      }
      await txn.insert('customer_loans',{
        'id':id,
        'business_date':(businessDate??DateTime.now()).toIso8601String().split('T').first,
        'customer_id':customerId,
        'amount':amount,
        'type':type,
        'note':note,
        'created_at':old.isEmpty?now:old.first['created_at'],
        'updated_at':now,
        'sync_state':0,
      });
      final delta=type=='payment'?-amount:amount;
      await txn.rawUpdate(
        'UPDATE customers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
        [delta,now,customerId],
      );
    });
  }

  Future<void> saveSalesmanLoan({
    required String id,
    required String salesmanId,
    required double amount,
    required String type,
    String? note,
    DateTime? businessDate,
  }) async {
    if(amount<=0) throw ArgumentError.value(amount,'amount','Amount must be greater than zero.');
    if(type!='loan'&&type!='payment') throw ArgumentError.value(type,'type','Use loan or payment.');
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    final old=await db.query('salesman_loans',where:'id=?',whereArgs:[id],limit:1);
    if(old.isNotEmpty&&old.first['source']!='manual') {
      throw StateError('Automatic invoice ledger entries cannot be edited manually.');
    }
    await db.insert('salesman_loans',{
      'id':id,
      'business_date':(businessDate??DateTime.now()).toIso8601String().split('T').first,
      'salesman_id':salesmanId,
      'amount':amount,
      'type':type,
      'source':'manual',
      'linked_sale_id':null,
      'note':note,
      'created_at':old.isEmpty?now:old.first['created_at'],
      'updated_at':now,
      'sync_state':0,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<void> saveSupplierTransaction({
    required String id,
    required String supplierId,
    required double amount,
    required String type,
    String? note,
    DateTime? businessDate,
  }) async {
    if(amount<=0) throw ArgumentError.value(amount,'amount','Amount must be greater than zero.');
    if(type!='payment'&&type!='received') throw ArgumentError.value(type,'type','Use payment or received.');
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final old=await txn.query('supplier_transactions',where:'id=?',whereArgs:[id],limit:1);
      if(old.isNotEmpty) {
        final o=old.first;
        final oldDelta=o['type']=='payment'?-_nDb(o['amount']):_nDb(o['amount']);
        await txn.rawUpdate(
          'UPDATE suppliers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
          [oldDelta,now,o['supplier_id']],
        );
        await txn.delete('supplier_transactions',where:'id=?',whereArgs:[id]);
      }
      await txn.insert('supplier_transactions',{
        'id':id,
        'business_date':(businessDate??DateTime.now()).toIso8601String().split('T').first,
        'supplier_id':supplierId,
        'amount':amount,
        'type':type,
        'note':note,
        'created_at':old.isEmpty?now:old.first['created_at'],
        'updated_at':now,
        'sync_state':0,
      });
      final delta=type=='payment'?-amount:amount;
      await txn.rawUpdate(
        'UPDATE suppliers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
        [delta,now,supplierId],
      );
    });
  }

  Future<void> saveCapital({
    required String id,
    required String name,
    required double amount,
    String? note,
    DateTime? businessDate,
  }) async {
    if(amount<=0) throw ArgumentError.value(amount,'amount','Amount must be greater than zero.');
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    final old=await db.query('capital',where:'id=?',whereArgs:[id],limit:1);
    await db.insert('capital',{
      'id':id,
      'business_date':(businessDate??DateTime.now()).toIso8601String().split('T').first,
      'name':name.trim(),
      'amount':amount,
      'note':note,
      'created_at':old.isEmpty?now:old.first['created_at'],
      'updated_at':now,
      'sync_state':0,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<void> saveStockAdjustment({
    required String id,
    required String productId,
    required double qty,
    String? note,
    String? source,
    String? fuelTankId,
    DateTime? businessDate,
  }) async {
    if(qty==0) throw ArgumentError.value(qty,'qty','Adjustment cannot be zero.');
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('stock_adjustments',{
        'id':id,
        'business_date':(businessDate??DateTime.now()).toIso8601String().split('T').first,
        'product_id':productId,
        'qty':qty,
        'note':note,
        'source':source,
        'fuel_tank_id':fuelTankId,
        'created_at':now,
        'updated_at':now,
        'sync_state':0,
      });
      await txn.rawUpdate(
        'UPDATE products SET stock=stock+?,updated_at=?,sync_state=0 WHERE id=?',
        [qty,now,productId],
      );
      if(fuelTankId!=null&&fuelTankId.isNotEmpty) {
        await txn.rawUpdate(
          'UPDATE fuel_tanks SET current_stock=current_stock+?,updated_at=?,sync_state=0 WHERE id=?',
          [qty,now,fuelTankId],
        );
      }
    });
  }

  Future<void> saveFuelClosing({
    required String id,
    required double openingCash,
    required double actualCash,
    required double cashIn,
    required double cashOut,
    String? note,
    DateTime? businessDate,
  }) async {
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    final expected=openingCash+cashIn-cashOut;
    await db.insert('fuel_closings',{
      'id':id,
      'business_date':(businessDate??DateTime.now()).toIso8601String().split('T').first,
      'opening_cash':openingCash,
      'cash_in':cashIn,
      'cash_out':cashOut,
      'expected_cash':expected,
      'actual_cash':actualCash,
      'variance':actualCash-expected,
      'note':note,
      'created_at':now,
      'updated_at':now,
      'sync_state':0,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<void> saveFuelTank({
    required String id,
    required String name,
    required String productId,
    required double capacity,
    required double openingLiters,
    String? note,
  }) async {
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final old=await txn.query('fuel_tanks',where:'id=?',whereArgs:[id],limit:1);
      final oldOpening=old.isEmpty?0:_nDb(old.first['opening_liters']);
      final oldProduct=old.isEmpty?null:old.first['product_id']?.toString();
      final oldCurrent=old.isEmpty?0:_nDb(old.first['current_stock']);
      final current=old.isEmpty?openingLiters:oldCurrent+(openingLiters-oldOpening);
      await txn.insert('fuel_tanks',{
        'id':id,
        'name':name.trim(),
        'product_id':productId,
        'fuel_type':'Fuel',
        'capacity':capacity,
        'opening_liters':openingLiters,
        'current_stock':current,
        'note':note,
        'updated_at':now,
        'sync_state':0,
      },conflictAlgorithm:ConflictAlgorithm.replace);

      if(oldProduct!=null&&oldProduct.isNotEmpty&&oldProduct!=productId) {
        final sum=await txn.rawQuery(
          'SELECT COALESCE(SUM(opening_liters),0) v FROM fuel_tanks WHERE product_id=?',
          [oldProduct],
        );
        await txn.update(
          'products',
          {'opening_qty':_nDb(sum.first['v']),'updated_at':now,'sync_state':0},
          where:'id=?',
          whereArgs:[oldProduct],
        );
      }
      final sum=await txn.rawQuery(
        'SELECT COALESCE(SUM(opening_liters),0) v FROM fuel_tanks WHERE product_id=?',
        [productId],
      );
      final product=await txn.query('products',columns:['opening_qty','stock'],where:'id=?',whereArgs:[productId],limit:1);
      if(product.isNotEmpty) {
        final oldProductOpening=_nDb(product.first['opening_qty']);
        final newOpening=_nDb(sum.first['v']);
        await txn.update(
          'products',
          {
            'opening_qty':newOpening,
            'stock':_nDb(product.first['stock'])+(newOpening-oldProductOpening),
            'updated_at':now,
            'sync_state':0,
          },
          where:'id=?',
          whereArgs:[productId],
        );
      }
    });
  }

  Future<void> saveFuelNozzle({
    required String id,
    required String tankId,
    required String name,
    required double openingMeter,
    String? note,
  }) async {
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    final old=await db.query('fuel_nozzles',where:'id=?',whereArgs:[id],limit:1);
    final meter=old.isEmpty?openingMeter:_nDb(old.first['meter_reading']);
    await db.insert('fuel_nozzles',{
      'id':id,
      'tank_id':tankId,
      'name':name.trim(),
      'opening_meter':openingMeter,
      'meter_reading':meter,
      'price_per_unit':old.isEmpty?0:_nDb(old.first['price_per_unit']),
      'note':note,
      'updated_at':now,
      'sync_state':0,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<void> createFuelDelivery({
    required String id,
    required String supplierId,
    required String tankId,
    required double liters,
    required double costPerLiter,
    double paid=0,
    String? invoiceNo,
    String? note,
    DateTime? businessDate,
  }) async {
    final db=await database;
    final tank=await db.query('fuel_tanks',where:'id=?',whereArgs:[tankId],limit:1);
    if(tank.isEmpty) throw StateError('Fuel tank not found.');
    final productId=tank.first['product_id']?.toString();
    if(productId==null||productId.isEmpty) throw StateError('Fuel tank is not linked to a product.');
    await createPurchase(
      id:id,
      supplierId:supplierId,
      items:[{'product_id':productId,'qty':liters,'cost':costPerLiter}],
      paid:paid,
      invoiceNo:invoiceNo,
      note:note,
      source:'fuel_delivery',
      fuelTankId:tankId,
      businessDate:businessDate,
    );
    final now=DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE fuel_tanks SET current_stock=current_stock+?,updated_at=?,sync_state=0 WHERE id=?',
      [liters,now,tankId],
    );
  }

  Future<void> createFuelShift({
    required String id,
    required String nozzleId,
    String? salesmanId,
    String? customerId,
    String? shiftName,
    String? invoiceNo,
    required double openingMeter,
    required double closingMeter,
    required double pricePerLiter,
    double cashReceived=0,
    String? note,
    DateTime? businessDate,
  }) async {
    if(closingMeter<openingMeter) {
      throw ArgumentError('Closing meter cannot be below opening meter.');
    }
    final db=await database;
    final nozzle=await db.rawQuery(
      'SELECT n.*,t.id tank_id,t.product_id,p.name product_name,p.cost '
      'FROM fuel_nozzles n JOIN fuel_tanks t ON t.id=n.tank_id '
      'LEFT JOIN products p ON p.id=t.product_id WHERE n.id=? LIMIT 1',
      [nozzleId],
    );
    if(nozzle.isEmpty) throw StateError('Fuel nozzle not found.');
    final row=nozzle.first;
    final productId=row['product_id']?.toString();
    if(productId==null||productId.isEmpty) throw StateError('Nozzle tank is not linked to a product.');
    final liters=closingMeter-openingMeter;
    final saleId='fuel_sale_$id';
    final inv=(invoiceNo??'').trim().isEmpty
      ?'FUEL-${DateTime.now().millisecondsSinceEpoch}'
      :invoiceNo!.trim();
    await createSale(
      id:saleId,
      invoiceNo:inv,
      customerId:customerId,
      salesmanId:salesmanId,
      items:[{
        'product_id':productId,
        'product_name':row['product_name']??'Fuel',
        'qty':liters,
        'price':pricePerLiter,
        'discount':0.0,
        'cost':_nDb(row['cost']),
      }],
      paid:cashReceived,
      note:note,
      businessDate:businessDate,
    );
    final now=DateTime.now().toUtc().toIso8601String();
    final day=(businessDate??DateTime.now()).toIso8601String().split('T').first;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE fuel_tanks SET current_stock=current_stock-?,updated_at=?,sync_state=0 WHERE id=?',
        [liters,now,row['tank_id']],
      );
      await txn.rawUpdate(
        'UPDATE fuel_nozzles SET meter_reading=?,price_per_unit=?,updated_at=?,sync_state=0 WHERE id=?',
        [closingMeter,pricePerLiter,now,nozzleId],
      );
      await txn.insert('fuel_shifts',{
        'id':id,
        'business_date':day,
        'tank_id':row['tank_id'],
        'nozzle_id':nozzleId,
        'salesman_id':salesmanId,
        'customer_id':customerId,
        'sale_id':saleId,
        'shift_name':shiftName,
        'invoice_no':inv,
        'opening_meter':openingMeter,
        'closing_meter':closingMeter,
        'litres':liters,
        'price_per_unit':pricePerLiter,
        'total':liters*pricePerLiter,
        'cash_received':cashReceived,
        'expense':0,
        'started_at':now,
        'closed_at':now,
        'updated_at':now,
        'sync_state':0,
      });
    });
  }

  Future<void> saveMedicine({required String id,required String name,String? batchNo,String? expiryDate,double price=0,double stock=0}) async {
    final db=await database,now=DateTime.now().toUtc().toIso8601String();
    await db.insert('products',{'id':id,'name':name.trim(),'category':'Pharmacy','price':price,'stock':stock,'unit':'pcs','batch_no':batchNo,'expiry_date':expiryDate,'updated_at':now,'sync_state':0},conflictAlgorithm:ConflictAlgorithm.replace);
  }

  String _recycleTable(String section) {
    const map={
      'sales':'sales',
      'purchases':'purchases',
      'salesmen':'salesmen',
      'customerLoans':'customer_loans',
      'salesmanLoans':'salesman_loans',
      'supplierTransactions':'supplier_transactions',
      'expenses':'expenses',
      'capital':'capital',
      'stockAdjustments':'stock_adjustments',
      'customers':'customers',
      'suppliers':'suppliers',
      'products':'products',
      'sarafiExchange':'fx_exchanges',
      'sarafiMovement':'fx_cash',
    };
    final table=map[section];
    if(table==null) throw ArgumentError.value(section,'section','Unsupported v15 section.');
    return table;
  }

  Future<void> softDeleteById(String section,String id) async {
    final db=await database;
    final table=_recycleTable(section);
    await db.transaction((txn) async {
      final found=await txn.query(table,where:'id=?',whereArgs:[id],limit:1);
      if(found.isEmpty) throw StateError('Record not found.');
      final row=Map<String,Object?>.from(found.first);
      final linked=<String,dynamic>{};
      final now=DateTime.now().toUtc().toIso8601String();

      if(section=='sales') {
        final items=await txn.query('sale_items',where:'sale_id=?',whereArgs:[id]);
        final autoLoans=await txn.query('salesman_loans',where:'linked_sale_id=?',whereArgs:[id]);
        linked['sale_items']=items;
        linked['salesman_loans']=autoLoans;
        for(final item in items) {
          final pid=item['product_id']?.toString();
          if(pid!=null&&pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock=stock+?,updated_at=?,sync_state=0 WHERE id=?',
              [_nDb(item['qty']),now,pid],
            );
          }
        }
        final cid=row['customer_id']?.toString();
        if(cid!=null&&cid.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE customers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['total'])-_nDb(row['paid']),now,cid],
          );
        }
        await txn.delete('salesman_loans',where:'linked_sale_id=?',whereArgs:[id]);
        await txn.delete('sale_items',where:'sale_id=?',whereArgs:[id]);
      } else if(section=='purchases') {
        final items=await txn.query('purchase_items',where:'purchase_id=?',whereArgs:[id]);
        linked['purchase_items']=items;
        for(final item in items) {
          final pid=item['product_id']?.toString();
          if(pid!=null&&pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock=stock-?,updated_at=?,sync_state=0 WHERE id=?',
              [_nDb(item['qty']),now,pid],
            );
          }
        }
        final sid=row['supplier_id']?.toString();
        if(sid!=null&&sid.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE suppliers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['due']),now,sid],
          );
        }
        await txn.delete('purchase_items',where:'purchase_id=?',whereArgs:[id]);
      } else if(section=='customerLoans') {
        final cid=row['customer_id']?.toString();
        if(cid!=null&&cid.isNotEmpty) {
          final delta=row['type']=='payment'?-_nDb(row['amount']):_nDb(row['amount']);
          await txn.rawUpdate(
            'UPDATE customers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
            [delta,now,cid],
          );
        }
      } else if(section=='supplierTransactions') {
        final sid=row['supplier_id']?.toString();
        if(sid!=null&&sid.isNotEmpty) {
          final delta=row['type']=='payment'?-_nDb(row['amount']):_nDb(row['amount']);
          await txn.rawUpdate(
            'UPDATE suppliers SET balance=balance-?,updated_at=?,sync_state=0 WHERE id=?',
            [delta,now,sid],
          );
        }
      } else if(section=='stockAdjustments') {
        final pid=row['product_id']?.toString();
        if(pid!=null&&pid.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE products SET stock=stock-?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['qty']),now,pid],
          );
        }
        final tank=row['fuel_tank_id']?.toString();
        if(tank!=null&&tank.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE fuel_tanks SET current_stock=current_stock-?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['qty']),now,tank],
          );
        }
      } else if(section=='sarafiExchange') {
        final cash=await txn.query('fx_cash',where:'ref_id=?',whereArgs:[id]);
        final ledger=await txn.query('fx_ledger',where:'ref_id=?',whereArgs:[id]);
        linked['fx_cash']=cash;
        linked['fx_ledger']=ledger;
        await txn.delete('fx_cash',where:'ref_id=?',whereArgs:[id]);
        await txn.delete('fx_ledger',where:'ref_id=?',whereArgs:[id]);
      } else if(section=='sarafiMovement') {
        final ref=row['ref_id']?.toString()??'';
        if(ref.isEmpty) throw StateError('Sarafi movement reference is missing.');
        final ledger=await txn.query('fx_ledger',where:'ref_id=?',whereArgs:[ref]);
        linked['fx_ledger']=ledger;
        await txn.delete('fx_ledger',where:'ref_id=?',whereArgs:[ref]);
      } else if(section=='customers') {
        final linkedCount=Sqflite.firstIntValue(await txn.rawQuery(
          'SELECT (SELECT COUNT(*) FROM sales WHERE customer_id=?)+'
          '(SELECT COUNT(*) FROM customer_loans WHERE customer_id=?)',
          [id,id],
        ))??0;
        if(linkedCount>0) throw StateError('Customer has linked sales/loans. Delete those records first.');
      } else if(section=='suppliers') {
        final linkedCount=Sqflite.firstIntValue(await txn.rawQuery(
          'SELECT (SELECT COUNT(*) FROM purchases WHERE supplier_id=?)+'
          '(SELECT COUNT(*) FROM supplier_transactions WHERE supplier_id=?)',
          [id,id],
        ))??0;
        if(linkedCount>0) throw StateError('Supplier has linked purchases/transactions. Delete those records first.');
      } else if(section=='salesmen') {
        final linkedCount=Sqflite.firstIntValue(await txn.rawQuery(
          'SELECT (SELECT COUNT(*) FROM sales WHERE salesman_id=?)+'
          '(SELECT COUNT(*) FROM salesman_loans WHERE salesman_id=?)',
          [id,id],
        ))??0;
        if(linkedCount>0) throw StateError('Salesman has linked sales/loans. Delete those records first.');
      } else if(section=='products') {
        final linkedCount=Sqflite.firstIntValue(await txn.rawQuery(
          'SELECT (SELECT COUNT(*) FROM sale_items WHERE product_id=?)+'
          '(SELECT COUNT(*) FROM purchase_items WHERE product_id=?)+'
          '(SELECT COUNT(*) FROM stock_adjustments WHERE product_id=?)',
          [id,id,id],
        ))??0;
        if(linkedCount>0) throw StateError('Product has linked stock history. Delete those records first.');
      }

      var recycleLabel=row['name']?.toString()??row['invoice_no']?.toString()??id;
      if(section=='sarafiExchange') {
        recycleLabel='Sarafi exchange ${row['business_date']??''}: ${row['from_currency']??''} → ${row['to_currency']??''}';
      } else if(section=='sarafiMovement') {
        recycleLabel='Sarafi ${row['kind']??'movement'} ${row['currency']??''} ${row['amount']??''}';
      }

      await txn.insert('recycle_bin',{
        'id':'recycle_${DateTime.now().microsecondsSinceEpoch}_$id',
        'section':section,
        'label':recycleLabel,
        'record_json':jsonEncode(row),
        'linked_records_json':jsonEncode(linked),
        'deleted_at':now,
      });
      await txn.delete(table,where:'id=?',whereArgs:[id]);
    });
  }

  double _nDb(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;

  Future<void> restoreRecycle(String recycleId) async {
    final db=await database;
    await db.transaction((txn) async {
      final found=await txn.query('recycle_bin',where:'id=?',whereArgs:[recycleId],limit:1);
      if(found.isEmpty) throw StateError('Recycle record not found.');
      final bin=found.first;
      final section=bin['section'].toString();
      final table=_recycleTable(section);
      final row=Map<String,Object?>.from(jsonDecode(bin['record_json'].toString()) as Map);
      final rawLinked=bin['linked_records_json']?.toString();
      final linked=rawLinked==null||rawLinked.isEmpty
        ?<String,dynamic>{}
        :Map<String,dynamic>.from(jsonDecode(rawLinked) as Map);
      final now=DateTime.now().toUtc().toIso8601String();

      await txn.insert(table,row,conflictAlgorithm:ConflictAlgorithm.abort);

      if(section=='sales') {
        for(final raw in (linked['sale_items'] as List? ?? const [])) {
          final item=Map<String,Object?>.from(raw as Map);
          await txn.insert('sale_items',item);
          final pid=item['product_id']?.toString();
          if(pid!=null&&pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock=stock-?,updated_at=?,sync_state=0 WHERE id=?',
              [_nDb(item['qty']),now,pid],
            );
          }
        }
        for(final raw in (linked['salesman_loans'] as List? ?? const [])) {
          await txn.insert('salesman_loans',Map<String,Object?>.from(raw as Map));
        }
        final cid=row['customer_id']?.toString();
        if(cid!=null&&cid.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE customers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['total'])-_nDb(row['paid']),now,cid],
          );
        }
      } else if(section=='purchases') {
        for(final raw in (linked['purchase_items'] as List? ?? const [])) {
          final item=Map<String,Object?>.from(raw as Map);
          await txn.insert('purchase_items',item);
          final pid=item['product_id']?.toString();
          if(pid!=null&&pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock=stock+?,updated_at=?,sync_state=0 WHERE id=?',
              [_nDb(item['qty']),now,pid],
            );
          }
        }
        final sid=row['supplier_id']?.toString();
        if(sid!=null&&sid.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE suppliers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['due']),now,sid],
          );
        }
      } else if(section=='customerLoans') {
        final cid=row['customer_id']?.toString();
        if(cid!=null&&cid.isNotEmpty) {
          final delta=row['type']=='payment'?-_nDb(row['amount']):_nDb(row['amount']);
          await txn.rawUpdate(
            'UPDATE customers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
            [delta,now,cid],
          );
        }
      } else if(section=='supplierTransactions') {
        final sid=row['supplier_id']?.toString();
        if(sid!=null&&sid.isNotEmpty) {
          final delta=row['type']=='payment'?-_nDb(row['amount']):_nDb(row['amount']);
          await txn.rawUpdate(
            'UPDATE suppliers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
            [delta,now,sid],
          );
        }
      } else if(section=='stockAdjustments') {
        final pid=row['product_id']?.toString();
        if(pid!=null&&pid.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE products SET stock=stock+?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['qty']),now,pid],
          );
        }
        final tank=row['fuel_tank_id']?.toString();
        if(tank!=null&&tank.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE fuel_tanks SET current_stock=current_stock+?,updated_at=?,sync_state=0 WHERE id=?',
            [_nDb(row['qty']),now,tank],
          );
        }
      } else if(section=='sarafiExchange') {
        for(final raw in (linked['fx_cash'] as List? ?? const [])) {
          await txn.insert('fx_cash',Map<String,Object?>.from(raw as Map));
        }
        for(final raw in (linked['fx_ledger'] as List? ?? const [])) {
          await txn.insert('fx_ledger',Map<String,Object?>.from(raw as Map));
        }
      } else if(section=='sarafiMovement') {
        for(final raw in (linked['fx_ledger'] as List? ?? const [])) {
          await txn.insert('fx_ledger',Map<String,Object?>.from(raw as Map));
        }
      }

      await txn.delete('recycle_bin',where:'id=?',whereArgs:[recycleId]);
    });
  }

  Future<void> deleteRecycleForever(String id) async {
    final db=await database;
    await db.delete('recycle_bin',where:'id=?',whereArgs:[id]);
  }

  Future<void> clearSectionToRecycle(String section) async {
    final db=await database;
    final table=_recycleTable(section);
    final ids=await db.query(table,columns:['id']);
    for(final row in ids) {
      await softDeleteById(section,row['id'].toString());
    }
  }

  Future<Map<String,num>> extendedReportTotals() async {
    final db=await database;
    Future<double> sum(String table,String expr) async {final r=await db.rawQuery('SELECT COALESCE(SUM('+expr+'),0) value FROM '+table);return (r.first['value'] as num?)?.toDouble()??0;}
    final sales=await sum('sales','total'),purchases=await sum('purchases','total'),expenses=await sum('expenses','amount');
    final cr=await db.rawQuery('SELECT COALESCE(SUM(si.qty*COALESCE(si.cost,p.cost,0)),0) value FROM sale_items si LEFT JOIN products p ON p.id=si.product_id');final cogs=(cr.first['value'] as num?)?.toDouble()??0;
    return {'sales':sales,'purchases':purchases,'expenses':expenses,'profit':sales-cogs-expenses,'due':await sum('sales','due'),'supplierDue':await sum('purchases','due'),'stockCost':await sum('products','stock*cost'),'stockRetail':await sum('products','stock*price')};
  }

  Future<Map<String, num>> dashboardTotals() async {
    final db = await database;
    Future<double> sum(String table, String field) async {
      final rows = await db.rawQuery('SELECT COALESCE(SUM($field),0) value FROM $table');
      return (rows.first['value'] as num?)?.toDouble() ?? 0;
    }
    final products = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    final customers = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
    return {
      'sales': await sum('sales', 'total'),
      'expenses': await sum('expenses', 'amount'),
      'products': products,
      'customers': customers,
      'due': await sum('sales', 'due'),
    };
  }
}
