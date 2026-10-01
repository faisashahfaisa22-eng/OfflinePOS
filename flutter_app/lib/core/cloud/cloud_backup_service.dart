import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';

class CloudBackupService {
  static final instance=CloudBackupService._();
  CloudBackupService._();

  Future<Map<String,dynamic>> snapshot() async {
    final Database db=await AppDatabase.instance.database;
    const tables=['products','customers','suppliers','salesmen','sales','sale_items','expenses','purchases','purchase_items','customer_loans','supplier_transactions','fuel_tanks','fuel_nozzles','fuel_shifts','users','settings'];
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
    final data=Map<String,dynamic>.from(payload['data'] as Map);
    final db=await AppDatabase.instance.database;
    await db.transaction((txn) async {
      const deleteOrder=['sale_items','purchase_items','fuel_shifts','fuel_nozzles','customer_loans','supplier_transactions','sales','purchases','fuel_tanks','salesmen','customers','suppliers','products','users','settings'];
      const insertOrder=['products','customers','suppliers','salesmen','fuel_tanks','fuel_nozzles','sales','sale_items','purchases','purchase_items','customer_loans','supplier_transactions','fuel_shifts','users','settings'];
      for(final table in deleteOrder){ await txn.delete(table); }
      for(final table in insertOrder){
        final rows=(data[table] as List?)??const [];
        for(final raw in rows){
          await txn.insert(table,Map<String,Object?>.from(raw as Map),conflictAlgorithm:ConflictAlgorithm.replace);
        }
      }
    });
    return true;
  }

  String encodeSnapshot(Map<String,dynamic> value)=>jsonEncode(value);
}
