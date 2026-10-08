import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../database/app_database.dart';
import '../security/crypto_utils.dart';
import '../security/local_auth_service.dart';

class CloudBackupInfo {
  final bool isCurrent;
  final int? historyId;
  final DateTime? createdAt;
  final DateTime? storedAt;
  final String reason;
  final String? stateSha256;
  final bool integrityProtected;
  final int format;

  const CloudBackupInfo({
    required this.isCurrent,
    required this.historyId,
    required this.createdAt,
    required this.storedAt,
    required this.reason,
    required this.stateSha256,
    required this.integrityProtected,
    required this.format,
  });

  String get versionKey =>
      isCurrent ? 'current' : 'history:${historyId ?? 'unknown'}';
}

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
    'fx_currencies',
    'fx_rates',
    'fx_parties',
    'fx_exchanges',
    'fx_hawala',
    'fx_ledger',
    'fx_cash',
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
    'fx_currencies',
    'fx_rates',
    'fx_parties',
    'fx_exchanges',
    'fx_hawala',
    'fx_ledger',
    'fx_cash',
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
    'fx_currencies',
    'fx_rates',
    'fx_parties',
    'fx_exchanges',
    'fx_hawala',
    'fx_ledger',
    'fx_cash',
    'recycle_bin',
    'users',
    'settings',
    'legacy_archives',
    'migration_state',
  ];

  Future<String> _pendingPath() async =>
      join(await getDatabasesPath(), _pendingFile);

  String _orderByFor(String table) =>
      table == 'settings' || table == 'migration_state' ? 'key' : 'id';

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }

  String _hashJson(dynamic value) => crypto.sha256
      .convert(utf8.encode(jsonEncode(_canonicalize(value))))
      .toString();

  String _hashBytes(List<int> value) =>
      crypto.sha256.convert(value).toString();

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Builds one internally consistent snapshot of the local database.
  ///
  /// A transaction is used for the reads so a sale/purchase cannot be captured
  /// half-way through while its related rows are still changing.
  Future<Map<String, dynamic>> snapshot() async {
    final Database db = await AppDatabase.instance.database;

    final data = await db.transaction<Map<String, dynamic>>((txn) async {
      final result = <String, dynamic>{};
      for (final table in _tables) {
        result[table] = await txn.query(
          table,
          orderBy: '${_orderByFor(table)} ASC',
        );
      }
      return result;
    });

    return {
      'format': 1,
      'app': 'QAMVIO POS Flutter',
      'schema_version': 7,
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
  Future<Map<String, dynamic>> encryptedEnvelope({
    String reason = 'manual',
  }) async {
    final auth = LocalAuthService.instance;
    if (!auth.unlocked) {
      throw const AuthException('Sign in first.');
    }

    final snap = await snapshot();
    final authUsers = [
      for (final u in auth.users)
        {
          'id': u.id,
          'loginId': u.loginId,
          'role': u.role.label,
          'salesmanId': u.salesmanId,
          'active': u.active,
          'createdAt': u.createdAt,
          'kekSalt': u.kekSalt,
          'wdekPw': u.wdekPw,
          'recSalt': u.recSalt,
          'wdekRec': u.wdekRec,
        },
    ];

    final key = await auth.backupKey();
    final plain = utf8.encode(jsonEncode(snap));
    final box = await CryptoUtils.encryptBox(plain, key);
    final created = DateTime.now().toUtc();
    final stateHash = _hashJson({
      'data': snap['data'],
      'auth_users': authUsers,
    });

    return {
      'format': 2,
      'app': 'QAMVIO POS Flutter',
      'enc': 'aes-gcm-256',
      'schema_version': 7,
      'backup_id':
          '${created.microsecondsSinceEpoch}-${stateHash.substring(0, 12)}',
      'reason': reason,
      'created_at': created.toIso8601String(),
      'state_sha256': stateHash,
      'integrity_sha256': _hashBytes(plain),
      'auth_users': authUsers,
      'iv': box['iv'],
      'ct': box['ct'],
    };
  }

  /// Called while the app is unlocked. The background worker cannot open the
  /// encrypted database, so it uploads this already-encrypted pending file.
  Future<void> prepareBackupFile({String reason = 'scheduled'}) async {
    if (!LocalAuthService.instance.unlocked) return;

    final env = await encryptedEnvelope(reason: reason);
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
    final now = DateTime.now().toUtc().toIso8601String();
    final nextState = payload['state_sha256'];

    // Avoid filling history with duplicate snapshots. Encryption uses a fresh
    // IV every time, so ciphertext always changes even when business data does
    // not. The stable state hash lets us only refresh the successful-upload
    // timestamp when the protected state is identical.
    if (nextState is String && nextState.isNotEmpty) {
      final current = await client
          .from('qamvio_flutter_backups')
          .select('payload')
          .eq('user_id', userId)
          .maybeSingle();
      final rawCurrent = current?['payload'];
      if (rawCurrent is Map &&
          rawCurrent['state_sha256']?.toString() == nextState) {
        await client
            .from('qamvio_flutter_backups')
            .update({'updated_at': now})
            .eq('user_id', userId);
        return;
      }
    }

    await client.from('qamvio_flutter_backups').upsert(
      {
        'user_id': userId,
        'payload': payload,
        'updated_at': now,
      },
      onConflict: 'user_id',
    );
  }

  CloudBackupInfo _infoFromEnvelope(
    Map<String, dynamic> payload, {
    required bool isCurrent,
    int? historyId,
    DateTime? storedAt,
  }) {
    return CloudBackupInfo(
      isCurrent: isCurrent,
      historyId: historyId,
      createdAt: _date(payload['created_at']),
      storedAt: storedAt,
      reason: payload['reason']?.toString() ??
          (isCurrent ? 'latest' : 'archived'),
      stateSha256: payload['state_sha256']?.toString(),
      integrityProtected:
          payload['integrity_sha256'] is String &&
          (payload['integrity_sha256'] as String).isNotEmpty,
      format: payload['format'] is num
          ? (payload['format'] as num).toInt()
          : 0,
    );
  }

  Future<bool> _historyBackendAvailable(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      await client
          .from('qamvio_flutter_backup_history')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '42P01' ||
          e.code == 'PGRST205' ||
          e.message.contains('qamvio_flutter_backup_history')) {
        return false;
      }
      rethrow;
    }
  }

  Future<List<CloudBackupInfo>> backupHistory({int limit = 20}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Connect your cloud account first.');
    }

    final result = <CloudBackupInfo>[];
    final current = await client
        .from('qamvio_flutter_backups')
        .select('payload, updated_at')
        .eq('user_id', user.id)
        .maybeSingle();

    if (current != null && current['payload'] is Map) {
      result.add(
        _infoFromEnvelope(
          Map<String, dynamic>.from(current['payload'] as Map),
          isCurrent: true,
          storedAt: _date(current['updated_at']),
        ),
      );
    }

    if (!await _historyBackendAvailable(client, user.id)) {
      return result;
    }

    final take = limit < 1 ? 1 : (limit > 50 ? 50 : limit);
    final rows = await client
        .from('qamvio_flutter_backup_history')
        .select('id, payload, archived_at')
        .eq('user_id', user.id)
        .order('archived_at', ascending: false)
        .limit(take);

    for (final raw in rows) {
      if (raw['payload'] is! Map) continue;
      final id = raw['id'];
      result.add(
        _infoFromEnvelope(
          Map<String, dynamic>.from(raw['payload'] as Map),
          isCurrent: false,
          historyId: id is num ? id.toInt() : int.tryParse(id.toString()),
          storedAt: _date(raw['archived_at']),
        ),
      );
    }
    return result;
  }

  Future<Map<String, dynamic>?> _loadBackupEnvelope(
    SupabaseClient client,
    String userId,
    CloudBackupInfo info,
  ) async {
    final row = info.isCurrent
        ? await client
            .from('qamvio_flutter_backups')
            .select('payload')
            .eq('user_id', userId)
            .maybeSingle()
        : await client
            .from('qamvio_flutter_backup_history')
            .select('payload')
            .eq('user_id', userId)
            .eq('id', info.historyId!)
            .maybeSingle();

    if (row == null || row['payload'] is! Map) return null;
    return Map<String, dynamic>.from(row['payload'] as Map);
  }

  Future<void> backupNow() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Connect your cloud account first (Cloud & Backup > Cloud account).',
      );
    }

    await _upload(
      client,
      user.id,
      await encryptedEnvelope(reason: 'manual'),
    );
  }

  /// Restores the latest cloud backup transactionally.
  ///
  /// Before destructive work, QAMVIO creates a cloud safety checkpoint when
  /// the version-history backend is available. After a successful restore it
  /// uploads the restored state again, so the pre-restore state remains in
  /// history as a rollback point.
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
        .select('payload, updated_at')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null || row['payload'] is! Map) return false;

    final env = Map<String, dynamic>.from(row['payload'] as Map);
    await _restoreEnvelope(
      client: client,
      userId: user.id,
      env: env,
      loginId: loginId,
      secret: secret,
      secretIsRecoveryCode: secretIsRecoveryCode,
    );
    return true;
  }

  Future<bool> restoreBackup({
    required CloudBackupInfo backup,
    required String loginId,
    required String secret,
    bool secretIsRecoveryCode = false,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;

    final env = await _loadBackupEnvelope(client, user.id, backup);
    if (env == null) return false;

    await _restoreEnvelope(
      client: client,
      userId: user.id,
      env: env,
      loginId: loginId,
      secret: secret,
      secretIsRecoveryCode: secretIsRecoveryCode,
    );
    return true;
  }

  Future<void> _restoreEnvelope({
    required SupabaseClient client,
    required String userId,
    required Map<String, dynamic> env,
    required String loginId,
    required String secret,
    required bool secretIsRecoveryCode,
  }) async {
    if (env['app'] != 'QAMVIO POS Flutter') {
      throw const FormatException('Unsupported QAMVIO Flutter backup format.');
    }

    Map<String, dynamic> payload;
    if (env['format'] == 2) {
      payload = await _decryptEnvelope(
        env,
        loginId,
        secret,
        secretIsRecoveryCode,
      );
    } else if (env['format'] == 1) {
      payload = env;
    } else {
      throw const FormatException('Unsupported QAMVIO Flutter backup format.');
    }

    final historyReady = await _historyBackendAvailable(client, userId);
    if (historyReady && LocalAuthService.instance.unlocked) {
      // If this upload fails, cancel before local data is touched.
      await _upload(
        client,
        userId,
        await encryptedEnvelope(reason: 'pre_restore'),
      );
    }

    await _applyDecryptedPayload(payload);

    if (historyReady && LocalAuthService.instance.unlocked) {
      try {
        await _upload(
          client,
          userId,
          await encryptedEnvelope(reason: 'restored'),
        );
      } catch (_) {
        // Local restore is already committed. Queue the restored encrypted
        // state so the background worker can reconcile cloud state later.
        await prepareBackupFile(reason: 'post_restore');
      }
    }
  }

  /// Validates [payload] and replaces every business table with its data in a
  /// single transaction (all or nothing).
  Future<void> _applyDecryptedPayload(Map<String, dynamic> payload) async {
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
      'fx_currencies',
      'fx_rates',
      'fx_parties',
      'fx_exchanges',
      'fx_hawala',
      'fx_ledger',
      'fx_cash',
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
  }

  /// Fresh install (no accounts on this device): downloads the latest backup of
  /// the already signed-in cloud account, unwraps the data key with [password],
  /// re-creates every account from the backup (passwords unchanged), restores
  /// the business data and signs the user in. Returns false when the cloud
  /// account has no backup.
  Future<bool> restoreFreshInstall({
    required String loginId,
    required String password,
  }) async {
    final auth = LocalAuthService.instance;
    if (auth.hasAccounts) {
      throw const AuthException('An account already exists on this device.');
    }

    final client = Supabase.instance.client;
    final cloudUser = client.auth.currentUser;
    if (cloudUser == null) return false;

    final row = await client
        .from('qamvio_flutter_backups')
        .select('payload')
        .eq('user_id', cloudUser.id)
        .maybeSingle();
    if (row == null) return false;

    final raw = row['payload'];
    if (raw is! Map) {
      throw const FormatException('QAMVIO cloud backup payload is invalid.');
    }
    final env = Map<String, dynamic>.from(raw);
    if (env['app'] != 'QAMVIO POS Flutter' || env['format'] != 2) {
      throw const FormatException(
        'This cloud backup was made by an older version and cannot restore accounts.',
      );
    }

    final rawUsers = env['auth_users'];
    if (rawUsers is! List || rawUsers.isEmpty) {
      throw const FormatException(
        'QAMVIO Flutter backup is missing user keys (auth_users).',
      );
    }
    final entries = <Map<String, dynamic>>[
      for (final e in rawUsers)
        if (e is Map) Map<String, dynamic>.from(e),
    ];

    final id = LocalAuthService.normalizeLoginId(loginId);
    final mine = entries.where((u) => u['loginId'] == id);
    if (mine.isEmpty) {
      throw const AuthException('This account is not part of the cloud backup.');
    }
    final u = mine.first;

    final iv = env['iv'];
    final ct = env['ct'];
    final salt = u['kekSalt'];
    final wrapped = u['wdekPw'];
    if (iv is! String || ct is! String || salt is! String || wrapped is! Map) {
      throw const FormatException('QAMVIO Flutter backup key material is incomplete.');
    }

    Uint8List dek;
    Map<String, dynamic> payload;
    try {
      final kek = await CryptoUtils.deriveKey(password, salt);
      dek = await CryptoUtils.decryptBox(Map<String, dynamic>.from(wrapped), kek);
      final key = await CryptoUtils.deriveBackupKey(dek);
      final plain = await CryptoUtils.decryptBox({'iv': iv, 'ct': ct}, key);
      _verifyPlainIntegrity(env, plain);
      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is! Map) {
        throw const FormatException('Decrypted QAMVIO backup payload is invalid.');
      }
      payload = Map<String, dynamic>.from(decoded);
    } on SecretBoxAuthenticationError {
      throw const AuthException('Wrong password for this account.');
    }

    await auth.installBackedUpAccounts(entries: entries, dek: dek);
    try {
      await _applyDecryptedPayload(payload);
    } catch (_) {
      await auth.discardRestoredAccounts();
      rethrow;
    }
    auth.completeRestoredSignIn(id);
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
      _verifyPlainIntegrity(env, plain);

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

  void _verifyPlainIntegrity(
    Map<String, dynamic> env,
    List<int> plain,
  ) {
    final expected = env['integrity_sha256'];
    if (expected is! String || expected.isEmpty) {
      // Backward compatibility with format-2 backups created before v16
      // history hardening. AES-GCM authentication still protects those copies.
      return;
    }
    final actual = _hashBytes(plain);
    if (actual != expected) {
      throw const FormatException(
        'Backup integrity verification failed. The backup is damaged.',
      );
    }
  }

  String encodeSnapshot(Map<String, dynamic> value) => jsonEncode(value);
}
