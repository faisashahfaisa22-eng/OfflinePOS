import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';

class CloudBackupService {
  static final instance=CloudBackupService._();
  CloudBackupService._();

  Future<Map<String,dynamic>> snapshot() async {
    final Database db=await AppDatabase.instance.database;
    const tables=['products','customers','suppliers','salesmen','sales','sale_items','expenses','purchases','purchase_items','customer_loans','salesman_loans','supplier_transactions','fuel_tanks','fuel_nozzles','fuel_shifts','users','settings','legacy_archives','migration_state'];
    final data=<String,dynamic>{};
    for(final table in tables){ data[table]=await db.query(table); }
    return {'format':1,'app':'QAMVIO POS Flutter','created_at':DateTime.now().toUtc().toIso8601String(),'data':data};
  }

  Future<void> backupNow() async {
    final client=Supabase.instance.client;
    final user=client.auth.currentUser;
    if(user==null) return;
    final payload=await snapshot();
    await client.from('qamvio_flutter_backups').upsert({
      'user_id':user.id,
      'payload':payload,
      'updated_at':DateTime.now().toUtc().toIso8601String(),
    },onConflict:'user_id');
  }

  Future<bool> restoreLatest() async {
    final client=Supabase.instance.client;
    final user=client.auth.currentUser;
    if(user==null) return false;
    final row=await client.from('qamvio_flutter_backups').select('payload').eq('user_id',user.id).maybeSingle();
    if(row==null) return false;
    final payload=Map<String,dynamic>.from(row['payload'] as Map);
    if(payload['format']!=1 || payload['app']!='QAMVIO POS Flutter') {
      throw const FormatException('Unsupported QAMVIO Flutter backup format.');
    }
    final rawData=payload['data'];
    if(rawData is! Map) {
      throw const FormatException('QAMVIO Flutter backup is missing table data.');
    }
    final data=Map<String,dynamic>.from(rawData);
    data.putIfAbsent('salesman_loans',()=> <dynamic>[]);
    const requiredTables=['products','customers','suppliers','salesmen','sales','sale_items','expenses','purchases','purchase_items','customer_loans','salesman_loans','supplier_transactions','fuel_tanks','fuel_nozzles','fuel_shifts','users','settings','legacy_archives','migration_state'];
    for(final table in requiredTables) {
      if(data[table] is! List) {
        throw FormatException('QAMVIO Flutter backup is incomplete: '+table+'.');
      }
    }
    final db=await AppDatabase.instance.database;
    await db.transaction((txn) async {
      const deleteOrder=['sale_items','purchase_items','fuel_shifts','fuel_nozzles','customer_loans','salesman_loans','supplier_transactions','sales','purchases','expenses','fuel_tanks','salesmen','customers','suppliers','products','users','settings','legacy_archives','migration_state'];
      const insertOrder=['products','customers','suppliers','salesmen','fuel_tanks','fuel_nozzles','sales','sale_items','purchases','purchase_items','customer_loans','salesman_loans','supplier_transactions','expenses','fuel_shifts','users','settings','legacy_archives','migration_state'];
      for(final table in deleteOrder){ await txn.delete(table); }
      for(final table in insertOrder){
        final rows=data[table] as List;
        for(final raw in rows){
          if(raw is! Map) throw FormatException('Invalid row in backup table '+table+'.');
          await txn.insert(table,Map<String,Object?>.from(raw),conflictAlgorithm:ConflictAlgorithm.replace);
        }
      }
      for(final table in requiredTables){
        final expected=(data[table] as List).length;
        final actual=Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM '+table))??0;
        if(actual!=expected){
          throw StateError('Restore validation failed for '+table+': expected '+expected.toString()+', found '+actual.toString()+'.');
        }
      }
    });
    return true;
  }

  String encodeSnapshot(Map<String,dynamic> value)=>jsonEncode(value);
}
