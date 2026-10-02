import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../security/crypto_utils.dart';

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
      version: 6,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2Tables(db);
        if (oldVersion < 3) await _createV3Tables(db);
        if (oldVersion < 4) await _createV4Tables(db);
        if (oldVersion < 5) await _createV5Tables(db);
        if (oldVersion < 6) await _createV6Tables(db);
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
    await db.execute('CREATE TABLE sales(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL,business_date TEXT,customer_id TEXT,salesman_id TEXT,subtotal REAL NOT NULL DEFAULT 0,discount REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,oil REAL NOT NULL DEFAULT 0,other REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id),FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
    await db.execute('CREATE TABLE sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,cost REAL,total REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE expenses(id TEXT PRIMARY KEY,name TEXT NOT NULL,category TEXT,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE purchases(id TEXT PRIMARY KEY,supplier_id TEXT,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))');
    await db.execute('CREATE TABLE purchase_items(id TEXT PRIMARY KEY,purchase_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,cost REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE customer_loans(id TEXT PRIMARY KEY,customer_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id))');
    await db.execute('CREATE TABLE salesman_loans(id TEXT PRIMARY KEY,salesman_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,source TEXT,linked_sale_id TEXT,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(salesman_id) REFERENCES salesmen(id),FOREIGN KEY(linked_sale_id) REFERENCES sales(id) ON DELETE SET NULL)');
    await db.execute('CREATE TABLE supplier_transactions(id TEXT PRIMARY KEY,supplier_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))');
    await db.execute('CREATE TABLE fuel_tanks(id TEXT PRIMARY KEY,name TEXT NOT NULL,fuel_type TEXT NOT NULL,capacity REAL NOT NULL DEFAULT 0,current_stock REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE fuel_nozzles(id TEXT PRIMARY KEY,tank_id TEXT NOT NULL,name TEXT NOT NULL,meter_reading REAL NOT NULL DEFAULT 0,price_per_unit REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id))');
    await db.execute('CREATE TABLE fuel_shifts(id TEXT PRIMARY KEY,nozzle_id TEXT NOT NULL,salesman_id TEXT,opening_meter REAL NOT NULL DEFAULT 0,closing_meter REAL,litres REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,cash_received REAL NOT NULL DEFAULT 0,expense REAL NOT NULL DEFAULT 0,started_at TEXT NOT NULL,closed_at TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(nozzle_id) REFERENCES fuel_nozzles(id),FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
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
    await addColumn('sales','oil','REAL NOT NULL DEFAULT 0');
    await addColumn('sales','other','REAL NOT NULL DEFAULT 0');
    await addColumn('sales','note','TEXT');

    await db.execute('CREATE TABLE IF NOT EXISTS capital(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,name TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS stock_adjustments(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,product_id TEXT NOT NULL,qty REAL NOT NULL DEFAULT 0,note TEXT,source TEXT,fuel_tank_id TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(product_id) REFERENCES products(id),FOREIGN KEY(fuel_tank_id) REFERENCES fuel_tanks(id))');
    await db.execute('CREATE TABLE IF NOT EXISTS fuel_closings(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,opening_cash REAL NOT NULL DEFAULT 0,cash_in REAL NOT NULL DEFAULT 0,cash_out REAL NOT NULL DEFAULT 0,expected_cash REAL NOT NULL DEFAULT 0,actual_cash REAL NOT NULL DEFAULT 0,variance REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS recycle_bin(id TEXT PRIMARY KEY,section TEXT NOT NULL,label TEXT,record_json TEXT NOT NULL,linked_records_json TEXT,deleted_at TEXT NOT NULL)');
  }

  Future<List<Map<String, Object?>>> products() async {
    final db = await database;
    return db.query('products', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveProduct({
    required String id, required String name, String? barcode, String? category,
    double cost = 0, double price = 0, double stock = 0, String unit = 'pcs',
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('products', {
      'id': id, 'name': name.trim(), 'barcode': barcode, 'category': category,
      'cost': cost, 'price': price, 'stock': stock, 'unit': unit,
      'updated_at': now, 'sync_state': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }


  Future<List<Map<String, Object?>>> customers() async {
    final db = await database;
    return db.query('customers', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveCustomer({
    required String id, required String name, String? phone, String? address,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('customers', {
      'id': id, 'name': name.trim(), 'phone': phone, 'address': address,
      'balance': 0, 'updated_at': now, 'sync_state': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> suppliers() async {
    final db = await database;
    return db.query('suppliers', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveSupplier({
    required String id, required String name, String? phone, String? address,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('suppliers', {
      'id': id, 'name': name.trim(), 'phone': phone, 'address': address,
      'balance': 0, 'updated_at': now, 'sync_state': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    bool active=true,
  }) async {
    final db=await database;
    final now=DateTime.now().toUtc().toIso8601String();
    await db.insert('salesmen',{
      'id':id,
      'name':name.trim(),
      'phone':phone?.trim(),
      'commission':commission,
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
    required String id, required String name, String? category,
    required double amount, String? note,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('expenses', {
      'id': id, 'name': name.trim(), 'category': category, 'amount': amount,
      'note': note, 'created_at': now, 'updated_at': now, 'sync_state': 0,
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
    required List<Map<String,Object?>> items,
    double discount=0,
    double paid=0,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      double subtotal = 0;
      for (final item in items) {
        final qty = (item['qty'] as num?)?.toDouble() ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        subtotal += qty * price;
      }
      final total = (subtotal - discount).clamp(0, double.infinity).toDouble();
      final due = (total - paid).clamp(0, double.infinity).toDouble();
      await txn.insert('sales', {
        'id':id,
        'invoice_no':invoiceNo,
        'customer_id':customerId,
        'salesman_id':salesmanId,
        'subtotal':subtotal,
        'discount':discount,
        'total':total,
        'paid':paid,
        'due':due,
        'created_at':now,
        'updated_at':now,
        'sync_state':0,
      });
      if(customerId!=null && customerId.isNotEmpty && due>0) {
        await txn.rawUpdate(
          'UPDATE customers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
          [due,now,customerId],
        );
      }
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final qty = (item['qty'] as num?)?.toDouble() ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final productId = item['product_id'] as String?;
        await txn.insert('sale_items', {
          'id': '${id}_$i', 'sale_id': id, 'product_id': productId,
          'product_name': item['product_name'], 'qty': qty, 'price': price,
          'cost': (item['cost'] as num?)?.toDouble(), 'total': qty * price,
        });
        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock = stock - ?, updated_at = ?, sync_state = 0 WHERE id = ?',
            [qty, now, productId],
          );
        }
      }
    });
  }

  Future<void> createPurchase({required String id,required String supplierId,required List<Map<String,Object?>> items,double paid=0}) async {
    final db=await database;
    await db.transaction((txn) async {
      final now=DateTime.now().toUtc().toIso8601String(); double total=0;
      for(final item in items){final qty=(item['qty'] as num?)?.toDouble()??0,cost=(item['cost'] as num?)?.toDouble()??0;total+=qty*cost;}
      final due=(total-paid).clamp(0,double.infinity).toDouble();
      await txn.insert('purchases',{'id':id,'supplier_id':supplierId,'total':total,'paid':paid,'due':due,'created_at':now,'updated_at':now,'sync_state':0});
      for(var i=0;i<items.length;i++){final item=items[i],productId=item['product_id']?.toString();final qty=(item['qty'] as num?)?.toDouble()??0,cost=(item['cost'] as num?)?.toDouble()??0;final p=await txn.query('products',columns:['name'],where:'id=?',whereArgs:[productId],limit:1);await txn.insert('purchase_items',{'id':id+'_'+i.toString(),'purchase_id':id,'product_id':productId,'product_name':p.isEmpty?'Product':p.first['name'],'qty':qty,'cost':cost,'total':qty*cost});await txn.rawUpdate('UPDATE products SET stock=stock+?,cost=?,updated_at=?,sync_state=0 WHERE id=?',[qty,cost,now,productId]);}
      await txn.rawUpdate('UPDATE suppliers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',[due,now,supplierId]);
    });
  }

  Future<void> saveCustomerLoan({required String id,required String customerId,required double amount,required String type,String? note}) async {
    final db=await database,now=DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {await txn.insert('customer_loans',{'id':id,'customer_id':customerId,'amount':amount,'type':type,'note':note,'created_at':now,'updated_at':now,'sync_state':0});final delta=type=='payment'?-amount:amount;await txn.rawUpdate('UPDATE customers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',[delta,now,customerId]);});
  }

  Future<void> saveSalesmanLoan({required String id,required String salesmanId,required double amount,required String type,String? note}) async {
    if(amount<=0) throw ArgumentError.value(amount,'amount','Amount must be greater than zero.');
    if(type!='loan' && type!='payment') throw ArgumentError.value(type,'type','Use loan or payment.');
    final db=await database,now=DateTime.now().toUtc().toIso8601String();
    await db.insert('salesman_loans',{
      'id':id,'salesman_id':salesmanId,'amount':amount,'type':type,
      'source':'manual','linked_sale_id':null,'note':note,
      'created_at':now,'updated_at':now,'sync_state':0,
    });
  }

  Future<void> saveSupplierTransaction({required String id,required String supplierId,required double amount,required String type,String? note}) async {
    if(amount<=0) throw ArgumentError.value(amount,'amount','Amount must be greater than zero.');
    if(type!='payment' && type!='received') throw ArgumentError.value(type,'type','Use payment or received.');
    final db=await database,now=DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('supplier_transactions',{
        'id':id,'supplier_id':supplierId,'amount':amount,'type':type,'note':note,
        'created_at':now,'updated_at':now,'sync_state':0,
      });
      final delta=type=='payment'?-amount:amount;
      await txn.rawUpdate(
        'UPDATE suppliers SET balance=balance+?,updated_at=?,sync_state=0 WHERE id=?',
        [delta,now,supplierId],
      );
    });
  }

  Future<void> saveMedicine({required String id,required String name,String? batchNo,String? expiryDate,double price=0,double stock=0}) async {
    final db=await database,now=DateTime.now().toUtc().toIso8601String();
    await db.insert('products',{'id':id,'name':name.trim(),'category':'Pharmacy','price':price,'stock':stock,'unit':'pcs','batch_no':batchNo,'expiry_date':expiryDate,'updated_at':now,'sync_state':0},conflictAlgorithm:ConflictAlgorithm.replace);
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
