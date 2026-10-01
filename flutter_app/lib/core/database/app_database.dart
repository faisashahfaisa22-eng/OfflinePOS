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
      version: 3,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2Tables(db);
        if (oldVersion < 3) await _createV3Tables(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('CREATE TABLE products(id TEXT PRIMARY KEY,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,cost REAL NOT NULL DEFAULT 0,price REAL NOT NULL DEFAULT 0,stock REAL NOT NULL DEFAULT 0,unit TEXT,batch_no TEXT,expiry_date TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE customers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE suppliers(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,address TEXT,balance REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE salesmen(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT,commission REAL NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE sales(id TEXT PRIMARY KEY,invoice_no TEXT NOT NULL,customer_id TEXT,salesman_id TEXT,subtotal REAL NOT NULL DEFAULT 0,discount REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id),FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
    await db.execute('CREATE TABLE sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE expenses(id TEXT PRIMARY KEY,name TEXT NOT NULL,category TEXT,amount REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE purchases(id TEXT PRIMARY KEY,supplier_id TEXT,total REAL NOT NULL DEFAULT 0,paid REAL NOT NULL DEFAULT 0,due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))');
    await db.execute('CREATE TABLE purchase_items(id TEXT PRIMARY KEY,purchase_id TEXT NOT NULL,product_id TEXT,product_name TEXT NOT NULL,qty REAL NOT NULL,cost REAL NOT NULL,total REAL NOT NULL,FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE customer_loans(id TEXT PRIMARY KEY,customer_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(customer_id) REFERENCES customers(id))');
    await db.execute('CREATE TABLE supplier_transactions(id TEXT PRIMARY KEY,supplier_id TEXT NOT NULL,amount REAL NOT NULL DEFAULT 0,type TEXT NOT NULL,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(supplier_id) REFERENCES suppliers(id))');
    await db.execute('CREATE TABLE fuel_tanks(id TEXT PRIMARY KEY,name TEXT NOT NULL,fuel_type TEXT NOT NULL,capacity REAL NOT NULL DEFAULT 0,current_stock REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE fuel_nozzles(id TEXT PRIMARY KEY,tank_id TEXT NOT NULL,name TEXT NOT NULL,meter_reading REAL NOT NULL DEFAULT 0,price_per_unit REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(tank_id) REFERENCES fuel_tanks(id))');
    await db.execute('CREATE TABLE fuel_shifts(id TEXT PRIMARY KEY,nozzle_id TEXT NOT NULL,salesman_id TEXT,opening_meter REAL NOT NULL DEFAULT 0,closing_meter REAL,litres REAL NOT NULL DEFAULT 0,total REAL NOT NULL DEFAULT 0,cash_received REAL NOT NULL DEFAULT 0,expense REAL NOT NULL DEFAULT 0,started_at TEXT NOT NULL,closed_at TEXT,updated_at TEXT NOT NULL,sync_state INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(nozzle_id) REFERENCES fuel_nozzles(id),FOREIGN KEY(salesman_id) REFERENCES salesmen(id))');
    await db.execute('CREATE TABLE users(id TEXT PRIMARY KEY,email TEXT,phone TEXT,display_name TEXT,role TEXT NOT NULL DEFAULT "Admin",cloud_user_id TEXT,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE sync_queue(id INTEGER PRIMARY KEY AUTOINCREMENT,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0)');
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
    required String id, required String invoiceNo, String? customerId,
    required List<Map<String, Object?>> items, double discount = 0, double paid = 0,
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
        'id': id, 'invoice_no': invoiceNo, 'customer_id': customerId,
        'subtotal': subtotal, 'discount': discount, 'total': total,
        'paid': paid, 'due': due, 'created_at': now, 'updated_at': now, 'sync_state': 0,
      });
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final qty = (item['qty'] as num?)?.toDouble() ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final productId = item['product_id'] as String?;
        await txn.insert('sale_items', {
          'id': '${id}_$i', 'sale_id': id, 'product_id': productId,
          'product_name': item['product_name'], 'qty': qty, 'price': price,
          'total': qty * price,
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

  Future<void> saveMedicine({required String id,required String name,String? batchNo,String? expiryDate,double price=0,double stock=0}) async {
    final db=await database,now=DateTime.now().toUtc().toIso8601String();
    await db.insert('products',{'id':id,'name':name.trim(),'category':'Pharmacy','price':price,'stock':stock,'unit':'pcs','batch_no':batchNo,'expiry_date':expiryDate,'updated_at':now,'sync_state':0},conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<Map<String,num>> extendedReportTotals() async {
    final db=await database;
    Future<double> sum(String table,String expr) async {final r=await db.rawQuery('SELECT COALESCE(SUM('+expr+'),0) value FROM '+table);return (r.first['value'] as num?)?.toDouble()??0;}
    final sales=await sum('sales','total'),purchases=await sum('purchases','total'),expenses=await sum('expenses','amount');
    final cr=await db.rawQuery('SELECT COALESCE(SUM(si.qty*COALESCE(p.cost,0)),0) value FROM sale_items si LEFT JOIN products p ON p.id=si.product_id');final cogs=(cr.first['value'] as num?)?.toDouble()??0;
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
