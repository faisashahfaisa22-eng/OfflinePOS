import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const _databaseName = 'qamvio_pos.db';

DatabaseFactory? _factory;

DatabaseFactory get _webFactory => _factory ??= createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sqlite3WasmUri: Uri.parse('sqlite3mc.wasm'),
        sharedWorkerUri: Uri.parse('sqflite_sw.js'),
        indexedDbName: 'qamvio_pos_secure_v16',
      ),
    );

Future<void> deleteQamvioDatabase() async {
  // On a fresh browser profile there may be no IndexedDB/SQLite database yet.
  // Some web-worker backends report that as an exception instead of treating
  // delete as a no-op, so check first. This also keeps failed fresh-restore
  // rollback safe and idempotent.
  final exists = await _webFactory.databaseExists(_databaseName);
  if (exists) {
    await _webFactory.deleteDatabase(_databaseName);
  }
}

/// Opens the browser database through SQLite3 Multiple Ciphers WASM.
///
/// QAMVIO deliberately uses the SQLCipher cipher scheme and the same raw
/// 256-bit DEK format as the Android/iOS database. The key is configured
/// before any schema query is executed.
Future<Database> openQamvioDatabase({
  required String keyHex,
  required int version,
  required Future<void> Function(Database db) onConfigure,
  required Future<void> Function(Database db, int version) onCreate,
  required Future<void> Function(Database db, int oldVersion, int newVersion)
      onUpgrade,
}) async {
  return _webFactory.openDatabase(
    _databaseName,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) async {
        // SQLite3MC's browser build uses its default ChaCha20-Poly1305
        // cipher. Supply QAMVIO's 256-bit DEK as raw key material so no
        // browser-side passphrase KDF is needed.
        await db.execute("PRAGMA key = 'raw:$keyHex'");

        // Force a real read immediately. Setting a key itself can appear to
        // succeed even when it is wrong; reading sqlite_master validates it.
        await db.rawQuery('SELECT count(*) FROM sqlite_master');
        await onConfigure(db);
      },
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    ),
  );
}
