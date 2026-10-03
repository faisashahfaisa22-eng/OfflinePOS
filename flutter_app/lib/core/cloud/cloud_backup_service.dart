import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../database/app_database.dart';
import '../security/crypto_utils.dart';
import '../security/local_auth_service.dart';

class CloudBackupService {
  static final instance = CloudBackupService._();
  CloudBackupService._();

  static const _pendingFile = 'pending_backup.json';

  static const _tables = <String>[
    'products',
    'customers',
    'suppliers',
    'salesmen',
    'sales',
    'sale_items',
    'expenses',
    'purchases',
    'purchase_items',
    'customer_loans',
    'salesman_loans',
    'supplier_transactions',
    'capital',
    'stock_adjustments',
    'fuel_tanks',
    'fuel_nozzles',
    'fuel_shifts',
    'fuel_closings',
    'recycle_bin',
    'users',
    'settings',
    'legacy_archives',
    'migration_state',
  ];

  static const _deleteOrder = <String>[
    'sale_items',
    'purchase_items',
    'stock_adjustments',
    'fuel_shifts',
    'fuel_closings',
    'fuel_nozzles',
    'customer_loans',
    'salesman_loans',
    'supplier_transactions',
    'sales',
    'purchases',
    'expenses',
    'capital',
    'recycle_bin',
    'fuel_tanks',
    'customers',
    'suppliers',
    'salesmen',
    'products',
    'users',
    'settings',
    'legacy_archives',
    'migration_state',
  ];

  static const _insertOrder = <String>[
    'products',
    'salesmen',
    'customers',
    'suppliers',
    'fuel_tanks',
    'fuel_nozzles',
    'sales',
    'sale_items',
    'purchases',
    'purchase_items',
    'customer_loans',
    'salesman_loans',
    'supplier_transactions',
    'expenses',
    'capital',
    'stock_adjustments',
    'fuel_shifts',
    'fuel_closings',
    'recycle_bin',
    'users',
    'settings',
    'legacy_archives',
    'migration_state',
  ];

  Future<String> _pendingPath() async =>
      join(await getDatabasesPath(), _pendingFile);

  /// Builds one internally consistent snapshot of the local database.
  ///
  /// A transaction is used for the reads so a sale/purchase cannot be captured
  /// half-way through while its related rows are still changing.
  Future<Map<String, dynamic>> snapshot() async {
    final Database db = await AppDatabase.instance.database;

    final data = await db.transaction<Map<String, dynamic>>((txn) async {
      final result = <String, dynamic>{};
      for (final table in _tables) {
        result[table] = await txn.query(table);
      }
      return result;
    });

    return {
      'format': 1,
      'app': 'QAMVIO POS Flutter',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
  }

  /// Encrypted envelope (format 2).
  ///
  /// Business data is AES-GCM encrypted with a sub-key derived from the local
  /// database key. Only wrapped key material is stored beside the ciphertext so
  /// a backup can be unlocked with an account password or recovery code.
  /// Plain business data never leaves the device.
  Future<Map<String, dynamic>> encryptedEnvelope() async {
    final auth = LocalAuthService.instance;
    if (!auth.unlocked) {
      throw const AuthException('Sign in first.');
    }

    final key = await auth.backupKey();
    final plain = utf8.encode(jsonEncode(await snapshot()));
    final box = await CryptoUtils.encryptBox(plain, key);

    return {
      'format': 2,
      'app': 'QAMVIO POS Flutter',
      'enc': 'aes-gcm-256',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'auth_users': [
        for (final u in auth.users)
          {
            'loginId': u.loginId,
            'kekSalt': u.kekSalt,
            'wdekPw': u.wdekPw,
            'recSalt': u.recSalt,
            'wdekRec': u.wdekRec,
          },
      ],
      'iv': box['iv'],
      'ct': box['ct'],
    };
  }

  /// Called while the app is unlocked. The background worker cannot open the
  /// encrypted database, so it uploads this already-encrypted pending file.
  Future<void> prepareBackupFile() async {
    if (!LocalAuthService.instance.unlocked) return;

    final env = await encryptedEnvelope();
    final path = await _pendingPath();
    final temp = File('$path.tmp');

    await temp.writeAsString(jsonEncode(env), flush: true);

    final target = File(path);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(path);
  }

  Future<bool> uploadPendingFile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;

    final file = File(await _pendingPath());
    if (!await file.exists()) return false;

    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) {
      throw const FormatException('Invalid pending QAMVIO backup file.');
    }

    final payload = Map<String, dynamic>.from(raw);
    _validateEnvelopeForUpload(payload);

    await _upload(client, user.id, payload);

    // It is a pending queue item, not a long-term local archive. Once the
    // server accepted it, remove it so Workmanager does not re-upload stale
    // data every day.
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  }

  void _validateEnvelopeForUpload(Map<String, dynamic> payload) {
    if (payload['app'] != 'QAMVIO POS Flutter' ||
        payload['format'] != 2 ||
        payload['enc'] != 'aes-gcm-256' ||
        payload['iv'] is! String ||
        payload['ct'] is! String ||
        payload['auth_users'] is! List) {
      throw const FormatException('Invalid encrypted QAMVIO backup envelope.');
    }
  }

  Future<void> _upload(
    SupabaseClient client,
    String userId,
    Map<String, dynamic> payload,
  ) async {
    await client.from('qamvio_flutter_backups').upsert(
      {
        'user_id': userId,
        'payload': payload,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  Future<void> backupNow() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Connect your cloud account first (Cloud & Backup > Cloud account).',
      );
    }

    await _upload(client, user.id, await encryptedEnvelope());
  }

  /// Restores the latest cloud backup transactionally.
  ///
  /// [loginId] + [secret] are credentials for an account that existed when the
  /// backup was made. [secretIsRecoveryCode] selects password vs recovery code.
  Future<bool> restoreLatest({
    required String loginId,
    required String secret,
    bool secretIsRecoveryCode = false,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;

    final row = await client
        .from('qamvio_flutter_backups')
        .select('payload')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) return false;

    final rawPayload = row['payload'];
    if (rawPayload is! Map) {
      throw const FormatException('QAMVIO cloud backup payload is invalid.');
    }

    var payload = Map<String, dynamic>.from(rawPayload);

    if (payload['app'] != 'QAMVIO POS Flutter') {
      throw const FormatException(
        'Unsupported QAMVIO Flutter backup format.',
      );
    }

    if (payload['format'] == 2) {
      payload = await _decryptEnvelope(
        payload,
        loginId,
        secret,
        secretIsRecoveryCode,
      );
    } else if (payload['format'] != 1) {
      throw const FormatException(
        'Unsupported QAMVIO Flutter backup format.',
      );
    }

    final rawData = payload['data'];
    if (rawData is! Map) {
      throw const FormatException(
        'QAMVIO Flutter backup is missing table data.',
      );
    }

    final data = Map<String, dynamic>.from(rawData);

    // Compatibility with older Flutter backups created before these tables
    // existed.
    data.putIfAbsent('salesman_loans', () => <dynamic>[]);
    for (final table in [
      'capital',
      'stock_adjustments',
      'fuel_closings',
      'recycle_bin',
    ]) {
      data.putIfAbsent(table, () => <dynamic>[]);
    }

    for (final table in _tables) {
      if (data[table] is! List) {
        throw FormatException(
          'QAMVIO Flutter backup is incomplete: $table.',
        );
      }
    }

    final db = await AppDatabase.instance.database;

    // All destructive work is inside one transaction. Any malformed row,
    // foreign-key failure, duplicate key or row-count mismatch rolls back the
    // entire restore instead of leaving a half-restored database.
    await db.transaction((txn) async {
      for (final table in _deleteOrder) {
        await txn.delete(table);
      }

      for (final table in _insertOrder) {
        final rows = data[table] as List;

        for (final raw in rows) {
          if (raw is! Map) {
            throw FormatException(
              'Invalid row in backup table $table.',
            );
          }

          await txn.insert(
            table,
            Map<String, Object?>.from(raw),
            // The database was cleared above; duplicates indicate a malformed
            // backup and should fail rather than silently replacing rows.
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }

      for (final table in _tables) {
        final expected = (data[table] as List).length;
        final actual = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM $table'),
            ) ??
            0;

        if (actual != expected) {
          throw StateError(
            'Restore validation failed for $table: '
            'expected $expected, found $actual.',
          );
        }
      }
    });

    return true;
  }

  Future<Map<String, dynamic>> _decryptEnvelope(
    Map<String, dynamic> env,
    String loginRaw,
    String secret,
    bool isRecovery,
  ) async {
    final id = LocalAuthService.normalizeLoginId(loginRaw);

    final rawUsers = env['auth_users'];
    if (rawUsers is! List || rawUsers.isEmpty) {
      throw const FormatException(
        'QAMVIO Flutter backup is missing user keys (auth_users).',
      );
    }

    final users = rawUsers.map((entry) {
      if (entry is! Map) {
        throw const FormatException(
          'Invalid auth_users entry in cloud backup.',
        );
      }
      return Map<String, dynamic>.from(entry);
    });

    final match = users.where((u) => u['loginId'] == id);
    if (match.isEmpty) {
      throw const AuthException(
        'This account is not part of the cloud backup.',
      );
    }

    final u = match.first;
    final salt = isRecovery ? u['recSalt'] : u['kekSalt'];
    final wrappedRaw = isRecovery ? u['wdekRec'] : u['wdekPw'];

    if (salt is! String || wrappedRaw is! Map) {
      throw const FormatException(
        'QAMVIO Flutter backup user key material is incomplete.',
      );
    }

    final iv = env['iv'];
    final ct = env['ct'];
    if (iv is! String || ct is! String) {
      throw const FormatException(
        'QAMVIO Flutter backup ciphertext is missing.',
      );
    }

    try {
      final kek = await CryptoUtils.deriveKey(
        isRecovery
            ? CryptoUtils.normalizeRecoveryCode(secret)
            : secret,
        salt,
      );

      final wrapped = Map<String, dynamic>.from(wrappedRaw);
      final dek = await CryptoUtils.decryptBox(wrapped, kek);
      final key = await CryptoUtils.deriveBackupKey(dek);
      final plain = await CryptoUtils.decryptBox(
        {'iv': iv, 'ct': ct},
        key,
      );

      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is! Map) {
        throw const FormatException(
          'Decrypted QAMVIO backup payload is invalid.',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } on SecretBoxAuthenticationError {
      throw const AuthException(
        'Wrong password or recovery code for this backup.',
      );
    }
  }

  String encodeSnapshot(Map<String, dynamic> value) => jsonEncode(value);
}
