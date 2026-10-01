import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_backup_service.dart';
import '../database/app_database.dart';

class LegacyMigrationResult {
  final bool migrated;
  final bool found;
  final String message;
  final Map<String,int> counts;

  const LegacyMigrationResult({
    required this.migrated,
    required this.found,
    required this.message,
    this.counts=const {},
  });
}

class LegacyCrypto {
  static final AesGcm _aes=AesGcm.with256bits();

  static List<int> _hex(String value) {
    final s=value.trim();
    if(s.length.isOdd) throw const FormatException('Invalid hexadecimal data.');
    return List<int>.generate(
      s.length~/2,
      (i)=>int.parse(s.substring(i*2,i*2+2),radix:16),
    );
  }

  static Future<List<int>> _pbkdf2(
    String password,
    String saltHex,
    int iterations,
  ) async {
    final algorithm=Pbkdf2(
      macAlgorithm:Hmac.sha256(),
      iterations:iterations,
      bits:256,
    );
    final key=await algorithm.deriveKeyFromPassword(
      password:password,
      nonce:utf8.encode(saltHex),
    );
    return key.extractBytes();
  }

  static Future<Uint8List> _decryptBox(
    Map<String,dynamic> box,
    List<int> keyBytes,
  ) async {
    final combined=_hex(box['ct']?.toString()??'');
    if(combined.length<16) {
      throw const FormatException('Encrypted legacy payload is too short.');
    }
    final clear=await _aes.decrypt(
      SecretBox(
        combined.sublist(0,combined.length-16),
        nonce:_hex(box['iv']?.toString()??''),
        mac:Mac(combined.sublist(combined.length-16)),
      ),
      secretKey:SecretKey(keyBytes),
    );
    return Uint8List.fromList(clear);
  }

  static Future<Map<String,dynamic>> decryptLegacyPayload(
    Map<String,dynamic> payload,
    String password,
  ) async {
    if(payload['encrypted']!=true) {
      final plain=payload['data']??payload;
      if(plain is Map) return Map<String,dynamic>.from(plain);
      throw const FormatException('Unsupported legacy backup payload.');
    }
    if(payload['format']!=2) {
      throw const FormatException('Unsupported encrypted legacy backup format.');
    }

    final rawBox=payload['db_box'];
    final rawMeta=payload['db_meta'];
    if(rawBox is! Map || rawMeta is! Map) {
      throw const FormatException('Legacy backup is incomplete.');
    }

    final box=Map<String,dynamic>.from(rawBox);
    final meta=Map<String,dynamic>.from(rawMeta);
    final salt=meta['salt']?.toString()??'';
    if(salt.isEmpty) {
      throw const FormatException('Legacy key metadata is missing.');
    }
    final iterations=(meta['iter'] as num?)?.toInt()??600000;
    final kek=await _pbkdf2(password,salt,iterations);

    try {
      List<int> dek=kek;
      final wrapped=meta['wdek_pw'];
      if(wrapped is Map) {
        dek=await _decryptBox(Map<String,dynamic>.from(wrapped),kek);
      }

      final clear=await _decryptBox(box,dek);
      final decoded=jsonDecode(utf8.decode(clear));
      if(decoded is! Map) {
        throw const FormatException('Legacy database did not decode to an object.');
      }
      return Map<String,dynamic>.from(decoded);
    } catch(e) {
      throw StateError(
        'The legacy backup was found, but the original local QAMVIO password could not decrypt it. '
        'No business data was changed. Details: '+e.toString(),
      );
    }
  }
}

class LegacyMigrationService {
  LegacyMigrationService._();
  static final instance=LegacyMigrationService._();

  Future<Database> get _db=>AppDatabase.instance.database;

  Future<Map<String,dynamic>?> _legacyRow() async {
    final client=Supabase.instance.client;
    final user=client.auth.currentUser;
    if(user==null) return null;
    final row=await client
      .from('qamvio_cloud_backups')
      .select('payload,updated_at')
      .eq('user_id',user.id)
      .maybeSingle();
    return row==null?null:Map<String,dynamic>.from(row);
  }

  Future<bool> _hasBusinessData() async {
    final db=await _db;
    const tables=[
      'products','customers','suppliers','salesmen','sales','purchases',
      'expenses','customer_loans','supplier_transactions','fuel_tanks',
      'fuel_nozzles','fuel_shifts'
    ];
    for(final table in tables) {
      final count=Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM '+table),
      )??0;
      if(count>0) return true;
    }
    return false;
  }

  Future<bool> _completed() async {
    final db=await _db;
    final rows=await db.query(
      'migration_state',
      columns:['value'],
      where:'key=?',
      whereArgs:['legacy_cloud_v2'],
      limit:1,
    );
    return rows.isNotEmpty && rows.first['value']=='complete';
  }

  Future<bool> hasPendingMigration() async {
    if(await _hasBusinessData()) return false;
    if(await _completed()) return false;
    try {
      return await _legacyRow()!=null;
    } catch(_) {
      return false;
    }
  }

  Future<LegacyMigrationResult> migrateFromLegacyCloud({
    required String legacyPassword,
  }) async {
    if(legacyPassword.isEmpty) {
      return const LegacyMigrationResult(
        migrated:false,
        found:true,
        message:'Enter the original local QAMVIO password.',
      );
    }
    if(await _hasBusinessData()) {
      return const LegacyMigrationResult(
        migrated:false,
        found:true,
        message:'Migration refused: the Flutter database already contains business data.',
      );
    }
    if(await _completed()) {
      return const LegacyMigrationResult(
        migrated:false,
        found:true,
        message:'Legacy migration has already completed on this database.',
      );
    }

    final row=await _legacyRow();
    if(row==null) {
      return const LegacyMigrationResult(
        migrated:false,
        found:false,
        message:'No legacy QAMVIO cloud backup was found for this account.',
      );
    }
    final raw=row['payload'];
    if(raw is! Map) {
      throw const FormatException('Legacy cloud backup payload is invalid.');
    }

    final decrypted=await LegacyCrypto.decryptLegacyPayload(
      Map<String,dynamic>.from(raw),
      legacyPassword,
    );
    final counts=await _import(
      decrypted,
      sourceUpdatedAt:row['updated_at']?.toString(),
    );

    try {
      await CloudBackupService.instance.backupNow();
    } catch(_) {
      // Local migration is already committed. Scheduled backup can retry.
    }

    final total=counts.values.fold<int>(0,(a,b)=>a+b);
    return LegacyMigrationResult(
      migrated:true,
      found:true,
      counts:counts,
      message:'Legacy QAMVIO migration completed safely. '
        +total.toString()
        +' normalized rows were validated. The complete decrypted legacy snapshot '
        'was also archived locally for recovery.',
    );
  }

  List<Map<String,dynamic>> _rows(
    Map<String,dynamic> legacy,
    String key,
  ) {
    final value=legacy[key];
    if(value is! List) return <Map<String,dynamic>>[];
    return value
      .whereType<Map>()
      .map((x)=>Map<String,dynamic>.from(x))
      .toList();
  }

  List<Map<String,dynamic>> _lines(Map<String,dynamic> row) {
    final value=row['lines'];
    if(value is! List) return <Map<String,dynamic>>[];
    return value
      .whereType<Map>()
      .map((x)=>Map<String,dynamic>.from(x))
      .toList();
  }

  double _n(dynamic value) {
    if(value is num) return value.toDouble();
    return double.tryParse(value?.toString()??'')??0;
  }

  String _text(dynamic value)=>value?.toString()??'';

  String _stamp(dynamic value,String fallback) {
    final s=_text(value).trim();
    if(s.isEmpty) return fallback;
    if(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
      return s+'T00:00:00.000Z';
    }
    return s;
  }

  String? _nullableStamp(dynamic value) {
    final s=_text(value).trim();
    return s.isEmpty?null:s;
  }

  Map<String,String> _ids(
    List<Map<String,dynamic>> input,
    String prefix,
  ) {
    final result=<String,String>{};
    for(var i=0;i<input.length;i++) {
      final old=_text(input[i]['id']).trim();
      final lookup=old.isEmpty?'@'+i.toString():old;
      result[lookup]=old.isEmpty?'legacy_'+prefix+'_'+i.toString():old;
    }
    return result;
  }

  String? _mapped(Map<String,String> ids,dynamic raw) {
    final key=_text(raw).trim();
    return key.isEmpty?null:ids[key];
  }

  Map<String,dynamic>? _findById(
    List<Map<String,dynamic>> rows,
    dynamic id,
  ) {
    final wanted=_text(id);
    for(final row in rows) {
      if(_text(row['id'])==wanted) return row;
    }
    return null;
  }

  double _saleTotal(Map<String,dynamic> sale) {
    var total=0.0;
    for(final line in _lines(sale)) {
      total+=_n(line['qty'])*_n(line['price'])-_n(line['haji']);
    }
    return total;
  }

  Future<Map<String,int>> _import(
    Map<String,dynamic> legacy, {
    String? sourceUpdatedAt,
  }) async {
    final db=await _db;
    if(await _hasBusinessData()) {
      throw StateError(
        'Flutter database is not empty; migration refused to prevent overwrite.',
      );
    }

    final now=DateTime.now().toUtc().toIso8601String();
    final archiveId=await db.insert('legacy_archives',{
      'source':'qamvio_cloud_backups_v2',
      'source_updated_at':sourceUpdatedAt,
      'archived_at':now,
      'status':'archived',
      'payload':jsonEncode(legacy),
    });

    final products=_rows(legacy,'products');
    final customers=_rows(legacy,'customers');
    final suppliers=_rows(legacy,'suppliers');
    final salesmen=_rows(legacy,'salesmen');
    final sales=_rows(legacy,'sales');
    final purchases=_rows(legacy,'purchases');
    final customerLoans=_rows(legacy,'customerLoans');
    final supplierTransactions=_rows(legacy,'supplierTransactions');
    final expenses=_rows(legacy,'expenses');
    final adjustments=_rows(legacy,'stockAdjustments');
    final fuelTanks=_rows(legacy,'fuelTanks');
    final fuelNozzles=_rows(legacy,'fuelNozzles');
    final fuelShifts=_rows(legacy,'fuelShifts');

    final productIds=_ids(products,'product');
    final customerIds=_ids(customers,'customer');
    final supplierIds=_ids(suppliers,'supplier');
    final salesmanIds=_ids(salesmen,'salesman');
    final tankIds=_ids(fuelTanks,'tank');
    final nozzleIds=_ids(fuelNozzles,'nozzle');

    double productStock(String oldProductId,Map<String,dynamic> product) {
      var stock=_n(product['openingQty']);
      for(final purchase in purchases) {
        for(final line in _lines(purchase)) {
          if(_text(line['productId'])==oldProductId) {
            stock+=_n(line['qty']);
          }
        }
      }
      for(final adjustment in adjustments) {
        if(_text(adjustment['productId'])==oldProductId) {
          stock+=_n(adjustment['qty']);
        }
      }
      for(final sale in sales) {
        for(final line in _lines(sale)) {
          if(_text(line['productId'])==oldProductId) {
            stock-=_n(line['qty']);
          }
        }
      }
      return stock;
    }

    double productCost(String oldProductId,Map<String,dynamic> product) {
      var cost=_n(product['costPrice']);
      var latest='';
      for(final purchase in purchases) {
        final date=_text(purchase['date']);
        for(final line in _lines(purchase)) {
          if(_text(line['productId'])==oldProductId &&
             date.compareTo(latest)>=0) {
            cost=_n(line['cost']);
            latest=date;
          }
        }
      }
      return cost;
    }

    double customerBalance(
      String oldCustomerId,
      Map<String,dynamic> customer,
    ) {
      var balance=_n(customer['opening']);
      for(final sale in sales) {
        if(_text(sale['customerId'])==oldCustomerId) {
          balance+=_saleTotal(sale)-_n(sale['received']);
        }
      }
      for(final loan in customerLoans) {
        if(_text(loan['customerId'])==oldCustomerId) {
          balance+=_n(loan['given'])-_n(loan['received']);
        }
      }
      return balance;
    }

    double supplierBalance(
      String oldSupplierId,
      Map<String,dynamic> supplier,
    ) {
      var balance=_n(supplier['opening']);
      for(final purchase in purchases) {
        if(_text(purchase['supplierId'])==oldSupplierId) {
          var total=_n(purchase['total']);
          if(total==0) {
            for(final line in _lines(purchase)) {
              total+=_n(line['qty'])*_n(line['cost']);
            }
          }
          balance+=total-_n(purchase['paid']);
        }
      }
      for(final tx in supplierTransactions) {
        if(_text(tx['supplierId'])==oldSupplierId) {
          balance+=_n(tx['received'])-_n(tx['paid']);
        }
      }
      return balance;
    }

    double tankStock(String oldTankId,Map<String,dynamic> tank) {
      var total=_n(tank['openingLiters']);
      final productId=_text(tank['productId']);
      for(final purchase in purchases) {
        if(_text(purchase['source'])=='fuel_delivery' &&
           _text(purchase['fuelTankId'])==oldTankId) {
          for(final line in _lines(purchase)) {
            if(_text(line['productId'])==productId) {
              total+=_n(line['qty']);
            }
          }
        }
      }
      for(final adjustment in adjustments) {
        if(_text(adjustment['fuelTankId'])==oldTankId) {
          total+=_n(adjustment['qty']);
        }
      }
      for(final shift in fuelShifts) {
        if(_text(shift['tankId'])==oldTankId) {
          total-=_n(shift['liters']);
        }
      }
      return total;
    }

    final inserted=<String,int>{
      'products':0,
      'customers':0,
      'suppliers':0,
      'salesmen':0,
      'sales':0,
      'sale_items':0,
      'purchases':0,
      'purchase_items':0,
      'customer_loans':0,
      'supplier_transactions':0,
      'expenses':0,
      'fuel_tanks':0,
      'fuel_nozzles':0,
      'fuel_shifts':0,
    };

    try {
      await db.transaction((txn) async {
        for(var i=0;i<products.length;i++) {
          final row=products[i];
          final oldId=_text(row['id']).trim();
          final lookup=oldId.isEmpty?'@'+i.toString():oldId;
          await txn.insert('products',{
            'id':productIds[lookup],
            'name':_text(row['name']).trim().isEmpty
              ?'Legacy Product '+(i+1).toString()
              :_text(row['name']).trim(),
            'sku':_text(row['sku']).trim().isEmpty?null:_text(row['sku']).trim(),
            'barcode':_text(row['barcode']).trim().isEmpty?null:_text(row['barcode']).trim(),
            'category':_text(row['category']).trim().isEmpty?null:_text(row['category']).trim(),
            'cost':productCost(oldId,row),
            'price':_n(row['salePrice']),
            'stock':productStock(oldId,row),
            'unit':_text(row['unit']).trim().isEmpty?'pcs':_text(row['unit']).trim(),
            'batch_no':_text(row['batchNo']).trim().isEmpty?null:_text(row['batchNo']).trim(),
            'expiry_date':_text(row['expiryDate']).trim().isEmpty?null:_text(row['expiryDate']).trim(),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['products']=inserted['products']!+1;
        }

        for(var i=0;i<customers.length;i++) {
          final row=customers[i];
          final oldId=_text(row['id']).trim();
          final lookup=oldId.isEmpty?'@'+i.toString():oldId;
          final address=_text(row['address']).trim().isEmpty
            ?_text(row['note']).trim()
            :_text(row['address']).trim();
          await txn.insert('customers',{
            'id':customerIds[lookup],
            'name':_text(row['name']).trim().isEmpty
              ?'Legacy Customer '+(i+1).toString()
              :_text(row['name']).trim(),
            'phone':_text(row['phone']).trim().isEmpty?null:_text(row['phone']).trim(),
            'address':address.isEmpty?null:address,
            'balance':customerBalance(oldId,row),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['customers']=inserted['customers']!+1;
        }

        for(var i=0;i<suppliers.length;i++) {
          final row=suppliers[i];
          final oldId=_text(row['id']).trim();
          final lookup=oldId.isEmpty?'@'+i.toString():oldId;
          final address=_text(row['address']).trim().isEmpty
            ?_text(row['note']).trim()
            :_text(row['address']).trim();
          await txn.insert('suppliers',{
            'id':supplierIds[lookup],
            'name':_text(row['name']).trim().isEmpty
              ?'Legacy Supplier '+(i+1).toString()
              :_text(row['name']).trim(),
            'phone':_text(row['phone']).trim().isEmpty?null:_text(row['phone']).trim(),
            'address':address.isEmpty?null:address,
            'balance':supplierBalance(oldId,row),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['suppliers']=inserted['suppliers']!+1;
        }

        for(var i=0;i<salesmen.length;i++) {
          final row=salesmen[i];
          final oldId=_text(row['id']).trim();
          final lookup=oldId.isEmpty?'@'+i.toString():oldId;
          await txn.insert('salesmen',{
            'id':salesmanIds[lookup],
            'name':_text(row['name']).trim().isEmpty
              ?'Legacy Salesman '+(i+1).toString()
              :_text(row['name']).trim(),
            'phone':_text(row['phone']).trim().isEmpty?null:_text(row['phone']).trim(),
            'commission':_n(row['commission']),
            'active':row['active']==false?0:1,
            'updated_at':now,
            'sync_state':0,
          });
          inserted['salesmen']=inserted['salesmen']!+1;
        }

        for(var i=0;i<fuelTanks.length;i++) {
          final row=fuelTanks[i];
          final oldId=_text(row['id']).trim();
          final lookup=oldId.isEmpty?'@'+i.toString():oldId;
          final linked=_findById(products,row['productId']);
          await txn.insert('fuel_tanks',{
            'id':tankIds[lookup],
            'name':_text(row['name']).trim().isEmpty
              ?'Legacy Tank '+(i+1).toString()
              :_text(row['name']).trim(),
            'fuel_type':linked==null
              ?_text(row['name'])
              :_text(linked['name']),
            'capacity':_n(row['capacity']),
            'current_stock':tankStock(oldId,row),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['fuel_tanks']=inserted['fuel_tanks']!+1;
        }

        for(var i=0;i<fuelNozzles.length;i++) {
          final row=fuelNozzles[i];
          final tankId=_mapped(tankIds,row['tankId']);
          if(tankId==null) continue;
          final oldId=_text(row['id']).trim();
          final lookup=oldId.isEmpty?'@'+i.toString():oldId;
          var meter=_n(row['openingMeter']);
          for(final shift in fuelShifts) {
            if(_text(shift['nozzleId'])==oldId &&
               _n(shift['closingMeter'])>meter) {
              meter=_n(shift['closingMeter']);
            }
          }
          final oldTank=_findById(fuelTanks,row['tankId']);
          final oldProduct=oldTank==null
            ?null
            :_findById(products,oldTank['productId']);
          await txn.insert('fuel_nozzles',{
            'id':nozzleIds[lookup],
            'tank_id':tankId,
            'name':_text(row['name']).trim().isEmpty
              ?'Legacy Nozzle '+(i+1).toString()
              :_text(row['name']).trim(),
            'meter_reading':meter,
            'price_per_unit':oldProduct==null?0:_n(oldProduct['salePrice']),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['fuel_nozzles']=inserted['fuel_nozzles']!+1;
        }

        for(var i=0;i<sales.length;i++) {
          final row=sales[i];
          final saleId=_text(row['id']).trim().isEmpty
            ?'legacy_sale_'+i.toString()
            :_text(row['id']).trim();
          final lines=_lines(row);
          var subtotal=0.0;
          var discount=0.0;
          for(final line in lines) {
            subtotal+=_n(line['qty'])*_n(line['price']);
            discount+=_n(line['haji']);
          }
          final total=(subtotal-discount).clamp(0,double.infinity).toDouble();
          final paid=_n(row['received']);
          await txn.insert('sales',{
            'id':saleId,
            'invoice_no':_text(row['invoice']).trim().isEmpty
              ?'LEGACY-'+(i+1).toString()
              :_text(row['invoice']).trim(),
            'customer_id':_mapped(customerIds,row['customerId']),
            'salesman_id':_mapped(salesmanIds,row['salesmanId']),
            'subtotal':subtotal,
            'discount':discount,
            'total':total,
            'paid':paid,
            'due':(total-paid).clamp(0,double.infinity).toDouble(),
            'created_at':_stamp(row['date'],now),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['sales']=inserted['sales']!+1;

          for(var j=0;j<lines.length;j++) {
            final line=lines[j];
            final qty=_n(line['qty']);
            final price=_n(line['price']);
            await txn.insert('sale_items',{
              'id':saleId+'_'+j.toString(),
              'sale_id':saleId,
              'product_id':_mapped(productIds,line['productId']),
              'product_name':_text(line['productName']).trim().isEmpty
                ?'Legacy Product'
                :_text(line['productName']).trim(),
              'qty':qty,
              'price':price,
              'cost':_n(line['costAtSale']),
              'total':qty*price,
            });
            inserted['sale_items']=inserted['sale_items']!+1;
          }

          final oil=_n(row['oil']);
          final other=_n(row['other']);
          if(oil>0) {
            await txn.insert('expenses',{
              'id':saleId+'_legacy_oil',
              'name':'Legacy sale oil expense',
              'category':'Oil',
              'amount':oil,
              'note':'Migrated from sale '+_text(row['invoice']),
              'created_at':_stamp(row['date'],now),
              'updated_at':now,
              'sync_state':0,
            });
            inserted['expenses']=inserted['expenses']!+1;
          }
          if(other>0) {
            await txn.insert('expenses',{
              'id':saleId+'_legacy_other',
              'name':'Legacy sale extra expense',
              'category':'Extra',
              'amount':other,
              'note':'Migrated from sale '+_text(row['invoice']),
              'created_at':_stamp(row['date'],now),
              'updated_at':now,
              'sync_state':0,
            });
            inserted['expenses']=inserted['expenses']!+1;
          }
        }

        for(var i=0;i<purchases.length;i++) {
          final row=purchases[i];
          final purchaseId=_text(row['id']).trim().isEmpty
            ?'legacy_purchase_'+i.toString()
            :_text(row['id']).trim();
          final lines=_lines(row);
          var total=_n(row['total']);
          if(total==0) {
            for(final line in lines) {
              total+=_n(line['qty'])*_n(line['cost']);
            }
          }
          final paid=_n(row['paid']);
          await txn.insert('purchases',{
            'id':purchaseId,
            'supplier_id':_mapped(supplierIds,row['supplierId']),
            'total':total,
            'paid':paid,
            'due':(total-paid).clamp(0,double.infinity).toDouble(),
            'created_at':_stamp(row['date'],now),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['purchases']=inserted['purchases']!+1;

          for(var j=0;j<lines.length;j++) {
            final line=lines[j];
            final qty=_n(line['qty']);
            final cost=_n(line['cost']);
            await txn.insert('purchase_items',{
              'id':purchaseId+'_'+j.toString(),
              'purchase_id':purchaseId,
              'product_id':_mapped(productIds,line['productId']),
              'product_name':_text(line['productName']).trim().isEmpty
                ?'Legacy Product'
                :_text(line['productName']).trim(),
              'qty':qty,
              'cost':cost,
              'total':qty*cost,
            });
            inserted['purchase_items']=inserted['purchase_items']!+1;
          }
        }

        for(var i=0;i<customerLoans.length;i++) {
          final row=customerLoans[i];
          final customerId=_mapped(customerIds,row['customerId']);
          if(customerId==null) continue;
          final given=_n(row['given']);
          final received=_n(row['received']);
          final base=_text(row['id']).trim().isEmpty
            ?'legacy_cl_'+i.toString()
            :_text(row['id']).trim();
          if(given>0) {
            await txn.insert('customer_loans',{
              'id':base+'_given',
              'customer_id':customerId,
              'amount':given,
              'type':'loan',
              'note':_text(row['note']),
              'created_at':_stamp(row['date'],now),
              'updated_at':now,
              'sync_state':0,
            });
            inserted['customer_loans']=inserted['customer_loans']!+1;
          }
          if(received>0) {
            await txn.insert('customer_loans',{
              'id':base+'_received',
              'customer_id':customerId,
              'amount':received,
              'type':'payment',
              'note':_text(row['note']),
              'created_at':_stamp(row['date'],now),
              'updated_at':now,
              'sync_state':0,
            });
            inserted['customer_loans']=inserted['customer_loans']!+1;
          }
        }

        for(var i=0;i<supplierTransactions.length;i++) {
          final row=supplierTransactions[i];
          final supplierId=_mapped(supplierIds,row['supplierId']);
          if(supplierId==null) continue;
          final paid=_n(row['paid']);
          final received=_n(row['received']);
          final base=_text(row['id']).trim().isEmpty
            ?'legacy_st_'+i.toString()
            :_text(row['id']).trim();
          if(paid>0) {
            await txn.insert('supplier_transactions',{
              'id':base+'_paid',
              'supplier_id':supplierId,
              'amount':paid,
              'type':'payment',
              'note':_text(row['note']),
              'created_at':_stamp(row['date'],now),
              'updated_at':now,
              'sync_state':0,
            });
            inserted['supplier_transactions']=inserted['supplier_transactions']!+1;
          }
          if(received>0) {
            await txn.insert('supplier_transactions',{
              'id':base+'_received',
              'supplier_id':supplierId,
              'amount':received,
              'type':'received',
              'note':_text(row['note']),
              'created_at':_stamp(row['date'],now),
              'updated_at':now,
              'sync_state':0,
            });
            inserted['supplier_transactions']=inserted['supplier_transactions']!+1;
          }
        }

        for(var i=0;i<expenses.length;i++) {
          final row=expenses[i];
          await txn.insert('expenses',{
            'id':_text(row['id']).trim().isEmpty
              ?'legacy_expense_'+i.toString()
              :_text(row['id']).trim(),
            'name':_text(row['name']).trim().isEmpty
              ?'Legacy Expense'
              :_text(row['name']).trim(),
            'category':_text(row['category']).trim().isEmpty
              ?null
              :_text(row['category']).trim(),
            'amount':_n(row['amount']),
            'note':_text(row['note']).trim().isEmpty
              ?null
              :_text(row['note']).trim(),
            'created_at':_stamp(row['date'],now),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['expenses']=inserted['expenses']!+1;
        }

        for(var i=0;i<fuelShifts.length;i++) {
          final row=fuelShifts[i];
          final nozzleId=_mapped(nozzleIds,row['nozzleId']);
          if(nozzleId==null) continue;
          final litres=_n(row['liters']);
          final total=_n(row['gross'])>0
            ?_n(row['gross'])
            :litres*_n(row['price']);
          await txn.insert('fuel_shifts',{
            'id':_text(row['id']).trim().isEmpty
              ?'legacy_fuel_shift_'+i.toString()
              :_text(row['id']).trim(),
            'nozzle_id':nozzleId,
            'salesman_id':_mapped(salesmanIds,row['salesmanId']),
            'opening_meter':_n(row['openingMeter']),
            'closing_meter':_n(row['closingMeter']),
            'litres':litres,
            'total':total,
            'cash_received':_n(row['received']),
            'expense':0,
            'started_at':_stamp(row['date'],now),
            'closed_at':_nullableStamp(row['updatedAt']),
            'updated_at':now,
            'sync_state':0,
          });
          inserted['fuel_shifts']=inserted['fuel_shifts']!+1;
        }

        for(final entry in inserted.entries) {
          final actual=Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM '+entry.key),
          )??0;
          if(actual!=entry.value) {
            throw StateError(
              'Migration validation failed for '+entry.key
              +': expected '+entry.value.toString()
              +', found '+actual.toString()+'.',
            );
          }
        }

        await txn.insert(
          'migration_state',
          {
            'key':'legacy_cloud_v2',
            'value':'complete',
            'updated_at':now,
          },
          conflictAlgorithm:ConflictAlgorithm.replace,
        );
        await txn.insert(
          'settings',
          {
            'key':'legacy_migration_archive_id',
            'value':archiveId.toString(),
            'updated_at':now,
          },
          conflictAlgorithm:ConflictAlgorithm.replace,
        );
      });

      await db.update(
        'legacy_archives',
        {'status':'imported'},
        where:'id=?',
        whereArgs:[archiveId],
      );
      return inserted;
    } catch(e) {
      await db.update(
        'legacy_archives',
        {'status':'import_failed'},
        where:'id=?',
        whereArgs:[archiveId],
      );
      rethrow;
    }
  }
}
