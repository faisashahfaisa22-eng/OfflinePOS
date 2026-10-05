import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

String _sqlcipherKey(String keyHex) => "x'$keyHex'";

Future<void> deleteQamvioDatabase() async {
  final root = await cipher.getDatabasesPath();
  final path = join(root, 'qamvio_pos.db');
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.delete();
  }
}

Future<Database> openQamvioDatabase({
  required String keyHex,
  required int version,
  required Future<void> Function(Database db) onConfigure,
  required Future<void> Function(Database db, int version) onCreate,
  required Future<void> Function(Database db, int oldVersion, int newVersion)
      onUpgrade,
}) async {
  final root = await cipher.getDatabasesPath();
  final path = join(root, 'qamvio_pos.db');

  await _recoverInterruptedPlainMigration(path, keyHex);
  await _encryptLegacyPlainDatabaseIfNeeded(path, keyHex);

  return cipher.openDatabase(
    path,
    password: _sqlcipherKey(keyHex),
    version: version,
    onConfigure: onConfigure,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}

Future<bool> _isPlainSqlite(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  final raf = await file.open();
  try {
    final head = await raf.read(16);
    return String.fromCharCodes(head).startsWith('SQLite format 3');
  } finally {
    await raf.close();
  }
}

Future<void> _verifyEncryptedDatabase(String path, String keyHex) async {
  final check = await cipher.openDatabase(
    path,
    password: _sqlcipherKey(keyHex),
    readOnly: true,
  );
  try {
    final tables = firstIntValue(
          await check.rawQuery(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table'",
          ),
        ) ??
        0;
    if (tables == 0) {
      throw StateError('Encrypted database verification found no tables.');
    }
    final integrity = await check.rawQuery('PRAGMA integrity_check');
    final result =
        integrity.isEmpty ? '' : integrity.first.values.first?.toString() ?? '';
    if (result.toLowerCase() != 'ok') {
      throw StateError('Encrypted database integrity check failed: $result');
    }
  } finally {
    await check.close();
  }
}

Future<void> _deleteSidecars(
  String base, {
  bool includeMain = false,
}) async {
  final suffixes = includeMain
      ? const ['', '-wal', '-shm', '-journal']
      : const ['-wal', '-shm', '-journal'];
  for (final suffix in suffixes) {
    final file = File('$base$suffix');
    if (await file.exists()) await file.delete();
  }
}

Future<void> _recoverInterruptedPlainMigration(
  String path,
  String keyHex,
) async {
  final backup = '$path.plain.bak';
  final main = File(path);
  final old = File(backup);
  if (!await old.exists()) return;

  if (!await main.exists()) {
    await old.rename(path);
    return;
  }

  if (await _isPlainSqlite(path)) {
    await _deleteSidecars(backup, includeMain: true);
    return;
  }

  try {
    await _verifyEncryptedDatabase(path, keyHex);
    await _deleteSidecars(backup, includeMain: true);
  } catch (_) {
    await _deleteSidecars(path, includeMain: true);
    await old.rename(path);
  }
}

Future<void> _encryptLegacyPlainDatabaseIfNeeded(
  String path,
  String keyHex,
) async {
  if (!await _isPlainSqlite(path)) return;

  final tmp = '$path.enc';
  final backup = '$path.plain.bak';
  await _deleteSidecars(tmp, includeMain: true);
  await _deleteSidecars(backup, includeMain: true);

  final plain = await cipher.openDatabase(path);
  int version;
  try {
    version =
        firstIntValue(await plain.rawQuery('PRAGMA user_version')) ?? 0;
    final safeTmp = tmp.replaceAll("'", "''");
    await plain.execute(
      "ATTACH DATABASE '$safeTmp' AS encrypted KEY \"${_sqlcipherKey(keyHex)}\"",
    );
    await plain.rawQuery("SELECT sqlcipher_export('encrypted')");
    await plain.execute('PRAGMA encrypted.user_version = $version');
    await plain.execute('DETACH DATABASE encrypted');
    try {
      await plain.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {
      // Not every journal mode supports or needs a WAL checkpoint.
    }
  } finally {
    await plain.close();
  }

  await _verifyEncryptedDatabase(tmp, keyHex);
  await _deleteSidecars(path);

  final original = File(path);
  await original.rename(backup);
  try {
    await File(tmp).rename(path);
    await _verifyEncryptedDatabase(path, keyHex);
    await _deleteSidecars(backup, includeMain: true);
  } catch (_) {
    await _deleteSidecars(path, includeMain: true);
    final rollback = File(backup);
    if (await rollback.exists()) await rollback.rename(path);
    rethrow;
  }
}
