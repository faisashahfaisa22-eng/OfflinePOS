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
    if (client.auth.currentUser == null || !await online) return 0;
    final db = await AppDatabase.instance.database;
    final rows = await db.query('sync_queue', orderBy: 'id ASC', limit: 250);
    var synced = 0;
    for (final row in rows) {
      try {
        final table = row['table_name'] as String;
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        payload['user_id'] = client.auth.currentUser!.id;
        await client.from('qamvio_$table').upsert(payload);
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [row['id']]);
        synced++;
      } catch (_) {
        await db.rawUpdate('UPDATE sync_queue SET attempts = attempts + 1 WHERE id = ?', [row['id']]);
      }
    }
    return synced;
  }

  Future<Map<String, int>> localCounts() async {
    final db = await AppDatabase.instance.database;
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table WHERE deleted = 0');
      return (rows.first['c'] as int?) ?? 0;
    }
    return {
      'products': await count('products'), 'customers': await count('customers'),
      'suppliers': await count('suppliers'), 'sales': await count('sales'),
      'expenses': await count('expenses'),
    };
  }
}
