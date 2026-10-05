import 'dart:typed_data';

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

const _storeDatabaseName = 'qamvio_encrypted_sqlite_v1';
const _storeName = 'files';
const _databaseKey = 'qamvio_pos.db';

Future<idb.Database> _openStore() {
  return idbFactoryBrowser.open(
    _storeDatabaseName,
    version: 1,
    onUpgradeNeeded: (event) {
      final db = event.database;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    },
  );
}

/// Loads the already-encrypted SQLite file bytes from browser IndexedDB.
///
/// Only ciphertext produced by SQLite3 Multiple Ciphers is stored here.
Future<Uint8List?> loadEncryptedDatabaseBytes() async {
  final db = await _openStore();
  try {
    final txn = db.transaction(_storeName, idb.idbModeReadOnly);
    final value = await txn.objectStore(_storeName).getObject(_databaseKey);
    await txn.completed;

    if (value == null) return null;
    if (value is Uint8List) return Uint8List.fromList(value);
    if (value is List<int>) return Uint8List.fromList(value);
    throw const FormatException('Invalid QAMVIO encrypted browser database.');
  } finally {
    db.close();
  }
}

/// Persists an encrypted SQLite file atomically in browser IndexedDB.
Future<void> saveEncryptedDatabaseBytes(Uint8List bytes) async {
  final db = await _openStore();
  try {
    final txn = db.transaction(_storeName, idb.idbModeReadWrite);
    await txn.objectStore(_storeName).put(Uint8List.fromList(bytes), _databaseKey);
    await txn.completed;
  } finally {
    db.close();
  }
}

/// Removes the persisted encrypted browser database.
Future<void> deleteEncryptedDatabaseBytes() async {
  final db = await _openStore();
  try {
    final txn = db.transaction(_storeName, idb.idbModeReadWrite);
    await txn.objectStore(_storeName).delete(_databaseKey);
    await txn.completed;
  } finally {
    db.close();
  }
}
