import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qamvio_pos/core/database/app_database.dart';

/// Money / stock correctness tests. They run on a real Android emulator with
/// the real SQLCipher database (see .github/workflows/accounting-tests.yml).
/// Every test makes its own product / customer / supplier, so tests do not
/// depend on each other.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final app=AppDatabase.instance;
  var n=0;
  String uid(String p)=>'$p-${DateTime.now().microsecondsSinceEpoch}-${n++}';

  Future<double> num_(String table,String field,String id) async {
    final db=await app.database;
    final r=await db.query(table,columns:[field],where:'id=?',whereArgs:[id]);
    return (r.first[field] as num).toDouble();
  }

  Future<String> product({double stock=100,double price=10,double cost=6}) async {
    final id=uid('p');
    await app.saveProduct(id:id,name:'Test $id',stock:stock,price:price,cost:cost);
    return id;
  }

  Future<String> customer() async {
    final id=uid('c');
    await app.saveCustomer(id:id,name:'Cust $id');
    return id;
  }

  Future<String> supplier() async {
    final id=uid('s');
    await app.saveSupplier(id:id,name:'Sup $id');
    return id;
  }

  Map<String,Object?> line(String pid,double qty,{double price=10,double discount=0}) =>
      {'product_id':pid,'product_name':'Test','qty':qty,'price':price,'discount':discount,'cost':6.0};

  setUpAll(() async {
    await app.deleteFile();
    await app.unlock(List<int>.generate(32,(i)=>i+1));
  });

  tearDownAll(() async {
    await app.lock();
  });

  group('Sales',() {
    test('credit sale reduces stock and raises customer balance',() async {
      final p=await product();
      final c=await customer();
      await app.createSale(id:uid('sale'),invoiceNo:'T1',customerId:c,items:[line(p,10)],paid:40);
      expect(await num_('products','stock',p),90);
      expect(await num_('customers','balance',c),60);
    });

    test('overpayment becomes recovery and lowers balance',() async {
      final p=await product();
      final c=await customer();
      final id=uid('sale');
      await app.createSale(id:id,invoiceNo:'T2',customerId:c,items:[line(p,10)],paid:130);
      expect(await num_('sales','recovery',id),30);
      expect(await num_('sales','due',id),0);
      expect(await num_('customers','balance',c),-30);
    });

    test('line and invoice discounts are summed',() async {
      final p=await product();
      final id=uid('sale');
      await app.createSale(id:id,invoiceNo:'T3',items:[line(p,2,discount:5)],discount:3,paid:0);
      expect(await num_('sales','subtotal',id),20);
      expect(await num_('sales','discount',id),8);
      expect(await num_('sales','total',id),12);
    });

    test('editing a sale reverses the old effects exactly',() async {
      final p=await product();
      final c=await customer();
      final id=uid('sale');
      await app.createSale(id:id,invoiceNo:'T4',customerId:c,items:[line(p,10)],paid:40);
      await app.createSale(id:id,invoiceNo:'T4',customerId:c,items:[line(p,5)],paid:0);
      expect(await num_('products','stock',p),95);
      expect(await num_('customers','balance',c),50);
      final db=await app.database;
      expect((await db.query('sale_items',where:'sale_id=?',whereArgs:[id])).length,1);
      expect((await db.query('sales',where:'id=?',whereArgs:[id])).length,1);
    });

    test('walk-in salesman sale with due creates one automatic salesman loan',() async {
      final p=await product();
      final db=await app.database;
      final sm=uid('sm');
      final now=DateTime.now().toUtc().toIso8601String();
      await db.insert('salesmen',{'id':sm,'name':'SM $sm','updated_at':now});
      final id=uid('sale');
      await app.createSale(id:id,invoiceNo:'T5',salesmanId:sm,items:[line(p,10)],paid:70);
      final loans=await db.query('salesman_loans',where:'linked_sale_id=?',whereArgs:[id]);
      expect(loans.length,1);
      expect((loans.first['amount'] as num).toDouble(),30);
      // Editing to fully paid removes the automatic loan.
      await app.createSale(id:id,invoiceNo:'T5',salesmanId:sm,items:[line(p,10)],paid:100);
      expect((await db.query('salesman_loans',where:'linked_sale_id=?',whereArgs:[id])).length,0);
    });
  });

  group('Purchases',() {
    test('purchase adds stock, updates cost, raises supplier balance',() async {
      final p=await product(stock:0,cost:1);
      final s=await supplier();
      await app.createPurchase(id:uid('pur'),supplierId:s,items:[{'product_id':p,'qty':20,'cost':5}],paid:40);
      expect(await num_('products','stock',p),20);
      expect(await num_('products','cost',p),5);
      expect(await num_('suppliers','balance',s),60);
    });

    test('editing a purchase reverses the old effects exactly',() async {
      final p=await product(stock:0);
      final s=await supplier();
      final id=uid('pur');
      await app.createPurchase(id:id,supplierId:s,items:[{'product_id':p,'qty':20,'cost':5}],paid:40);
      await app.createPurchase(id:id,supplierId:s,items:[{'product_id':p,'qty':10,'cost':5}],paid:0);
      expect(await num_('products','stock',p),10);
      expect(await num_('suppliers','balance',s),50);
    });
  });

  group('Loans and payments',() {
    test('customer loan then payment then edited payment',() async {
      final c=await customer();
      await app.saveCustomerLoan(id:uid('l'),customerId:c,amount:100,type:'loan');
      final pay=uid('l');
      await app.saveCustomerLoan(id:pay,customerId:c,amount:30,type:'payment');
      expect(await num_('customers','balance',c),70);
      await app.saveCustomerLoan(id:pay,customerId:c,amount:50,type:'payment');
      expect(await num_('customers','balance',c),50);
    });

    test('invalid loan amount or type is rejected and changes nothing',() async {
      final c=await customer();
      await expectLater(app.saveCustomerLoan(id:uid('l'),customerId:c,amount:0,type:'loan'),throwsArgumentError);
      await expectLater(app.saveCustomerLoan(id:uid('l'),customerId:c,amount:5,type:'gift'),throwsArgumentError);
      expect(await num_('customers','balance',c),0);
    });

    test('supplier payment lowers balance',() async {
      final s=await supplier();
      final p=await product(stock:0);
      await app.createPurchase(id:uid('pur'),supplierId:s,items:[{'product_id':p,'qty':10,'cost':10}],paid:0);
      await app.saveSupplierTransaction(id:uid('st'),supplierId:s,amount:40,type:'payment');
      expect(await num_('suppliers','balance',s),60);
    });
  });

  group('Stock',() {
    test('adjustments add and remove quantity',() async {
      final p=await product(stock:10);
      await app.saveStockAdjustment(id:uid('a'),productId:p,qty:5);
      await app.saveStockAdjustment(id:uid('a'),productId:p,qty:-3);
      expect(await num_('products','stock',p),12);
    });

    test('zero adjustment is rejected',() async {
      final p=await product(stock:10);
      await expectLater(app.saveStockAdjustment(id:uid('a'),productId:p,qty:0),throwsArgumentError);
      expect(await num_('products','stock',p),10);
    });
  });

  group('Recycle Bin',() {
    test('deleting a sale restores stock and balance, restoring puts them back',() async {
      final p=await product();
      final c=await customer();
      final id=uid('sale');
      await app.createSale(id:id,invoiceNo:'T9',customerId:c,items:[line(p,10)],paid:40);
      await app.softDeleteById('sales',id);
      expect(await num_('products','stock',p),100);
      expect(await num_('customers','balance',c),0);

      final db=await app.database;
      final bin=await db.query('recycle_bin',where:'section=?',whereArgs:['sales']);
      final entry=bin.firstWhere((r)=>r['record_json'].toString().contains(id));
      await app.restoreRecycle(entry['id'].toString());
      expect(await num_('products','stock',p),90);
      expect(await num_('customers','balance',c),60);
    });

    test('deleting a purchase removes its stock and supplier due',() async {
      final p=await product(stock:0);
      final s=await supplier();
      final id=uid('pur');
      await app.createPurchase(id:id,supplierId:s,items:[{'product_id':p,'qty':20,'cost':5}],paid:40);
      await app.softDeleteById('purchases',id);
      expect(await num_('products','stock',p),0);
      expect(await num_('suppliers','balance',s),0);
    });
  });
}
