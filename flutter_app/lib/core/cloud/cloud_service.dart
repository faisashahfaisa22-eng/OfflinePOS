import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';

class CloudService {
  CloudService(this.client);
  final SupabaseClient client;

  Future<bool> get online async {
    final state = await Connectivity().checkConnectivity();
    return !state.contains(ConnectivityResult.none);
  }

  Future<void> signUp({required String identifier, required String password}) async {
    final id = identifier.trim();
    if (id.contains('@')) {
      await client.auth.signUp(email: id.toLowerCase(), password: password);
    } else {
      await client.auth.signUp(phone: id, password: password);
    }
  }

  Future<void> signIn({required String identifier, required String password}) async {
    final id = identifier.trim();
    if (id.contains('@')) {
      await client.auth.signInWithPassword(email: id.toLowerCase(), password: password);
    } else {
      await client.auth.signInWithPassword(phone: id, password: password);
    }
  }

  Future<void> enqueue(String table, String id, String operation, Map<String, Object?> payload) async {
    final db = await AppDatabase.instance.database;
    await db.insert('sync_queue', {
      'table_name': table, 'record_id': id, 'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(), 'attempts': 0,
    });
  }

  Future<int> syncPending() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('sync_queue');
    return rows.length;
  }

  Future<void> backupNow() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Login to cloud first.');
    if (!await online) throw StateError('No internet connection.');
    final payload = await AppDatabase.instance.exportAll();
    await client.from('qamvio_flutter_backups').upsert({
      'user_id': user.id,
      'payload': payload,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<bool> restoreLatest() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Login to cloud first.');
    if (!await online) throw StateError('No internet connection.');
    final row = await client.from('qamvio_flutter_backups')
      .select('payload,updated_at').eq('user_id', user.id).maybeSingle();
    if (row == null) return false;
    final payload = row['payload'];
    if (payload is! Map) throw StateError('Cloud backup is invalid.');
    await AppDatabase.instance.restoreAll(Map<String,dynamic>.from(payload));
    return true;
  }

  Future<Map<String, int>> localCounts() async {
    final db = await AppDatabase.instance.database;
    Future<int> count(String table) async {
      final hasDeleted = !{'settings','accounts'}.contains(table);
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table' + (hasDeleted ? ' WHERE deleted = 0' : ''));
      return (rows.first['c'] as int?) ?? 0;
    }
    return {
      'products': await count('products'), 'customers': await count('customers'),
      'suppliers': await count('suppliers'), 'sales': await count('sales'),
      'purchases': await count('purchases'), 'expenses': await count('expenses'),
      'loans': await count('loans'), 'fuel_sales': await count('fuel_sales'),
    };
  }
}
