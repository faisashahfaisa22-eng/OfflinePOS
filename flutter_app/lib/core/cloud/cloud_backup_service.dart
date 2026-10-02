import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../database/app_database.dart';
import '../security/crypto_utils.dart';
import '../security/local_auth_service.dart';

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

  static const _pendingFile='pending_backup.json';

  Future<String> _pendingPath() async=>join(await getDatabasesPath(),_pendingFile);

  /// Encrypted envelope (format 2). The data is AES-GCM encrypted with a sub-key of the
  /// database key. The envelope also carries each user's *wrapped* data key
  /// (already protected by that user's password / recovery code), so a new device can
  /// restore with the original password. Plain business data never leaves the device.
  Future<Map<String,dynamic>> encryptedEnvelope() async {
    final auth=LocalAuthService.instance;
    if(!auth.unlocked) throw const AuthException('Sign in first.');
    final key=await auth.backupKey();
    final plain=utf8.encode(jsonEncode(await snapshot()));
    final box=await CryptoUtils.encryptBox(plain,key);
    return {
      'format':2,
      'app':'QAMVIO POS Flutter',
      'enc':'aes-gcm-256',
      'created_at':DateTime.now().toUtc().toIso8601String(),
      'auth_users':[
        for(final u in auth.users) {
          'loginId':u.loginId,
          'kekSalt':u.kekSalt,
          'wdekPw':u.wdekPw,
          'recSalt':u.recSalt,
          'wdekRec':u.wdekRec,
        }
      ],
      'iv':box['iv'],
      'ct':box['ct'],
    };
  }

  /// Called while the app is unlocked (e.g. when it goes to the background). The
  /// background worker cannot open the encrypted database, so it uploads this file.
  Future<void> prepareBackupFile() async {
    if(!LocalAuthService.instance.unlocked) return;
    final env=await encryptedEnvelope();
    await File(await _pendingPath()).writeAsString(jsonEncode(env),flush:true);
  }

  Future<bool> uploadPendingFile() async {
    final client=Supabase.instance.client;
    final user=client.auth.currentUser;
    if(user==null) return false;
    final f=File(await _pendingPath());
    if(!await f.exists()) return false;
    final payload=jsonDecode(await f.readAsString());
    await _upload(client,user.id,Map<String,dynamic>.from(payload as Map));
    return true;
  }

  Future<void> _upload(SupabaseClient client,String userId,Map<String,dynamic> payload) async {
    await client.from('qamvio_flutter_backups').upsert({
      'user_id':userId,
      'payload':payload,
      'updated_at':DateTime.now().toUtc().toIso8601String(),
    },onConflict:'user_id');
  }

  Future<void> backupNow() async {
    final client=Supabase.instance.client;
    final user=client.auth.currentUser;
    if(user==null) throw const AuthException('Connect your cloud account first (Cloud & Backup > Cloud account).');
    await _upload(client,user.id,await encryptedEnvelope());
  }

  /// Restores the latest cloud backup into the (empty or existing) local database.
  /// [loginId] + [secret] are the credentials of an account that existed when the backup
  /// was made; [secretIsRecoveryCode] selects password vs recovery code.
  Future<bool> restoreLatest({
    required String loginId,
    required String secret,
    bool secretIsRecoveryCode=false,
  }) async {
    final client=Supabase.instance.client;
    final user=client.auth.currentUser;
    if(user==null) return false;
    final row=await client.from('qamvio_flutter_backups').select('payload').eq('user_id',user.id).maybeSingle();
    if(row==null) return false;
    var payload=Map<String,dynamic>.from(row['payload'] as Map);
    if(payload['app']!='QAMVIO POS Flutter') {
      throw const FormatException('Unsupported QAMVIO Flutter backup format.');
    }
    if(payload['format']==2) {
      payload=await _decryptEnvelope(payload,loginId,secret,secretIsRecoveryCode);
    } else if(payload['format']!=1) {
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

  Future<Map<String,dynamic>> _decryptEnvelope(Map<String,dynamic> env,String loginRaw,String secret,bool isRecovery) async {
    final id=LocalAuthService.normalizeLoginId(loginRaw);
    final users=(env['auth_users'] as List).map((e)=>Map<String,dynamic>.from(e as Map));
    final match=users.where((u)=>u['loginId']==id);
    if(match.isEmpty) throw const AuthException('This account is not part of the cloud backup.');
    final u=match.first;
    try {
      final kek=await CryptoUtils.deriveKey(
        isRecovery?CryptoUtils.normalizeRecoveryCode(secret):secret,
        (isRecovery?u['recSalt']:u['kekSalt']) as String,
      );
      final wrapped=Map<String,dynamic>.from((isRecovery?u['wdekRec']:u['wdekPw']) as Map);
      final dek=await CryptoUtils.decryptBox(wrapped,kek);
      final key=await CryptoUtils.deriveBackupKey(dek);
      final plain=await CryptoUtils.decryptBox({'iv':env['iv'],'ct':env['ct']},key);
      return Map<String,dynamic>.from(jsonDecode(utf8.decode(plain)) as Map);
    } on SecretBoxAuthenticationError {
      throw const AuthException('Wrong password or recovery code for this backup.');
    }
  }

  String encodeSnapshot(Map<String,dynamic> value)=>jsonEncode(value);
}
