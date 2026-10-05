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
  await _webFactory.deleteDatabase(_databaseName);
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
        await db.execute("PRAGMA cipher = 'sqlcipher'");
        await db.execute('PRAGMA legacy = 4');
        await db.execute('PRAGMA key = "x\'$keyHex\'"');

        // Force a real read immediately. PRAGMA key itself reports success
        // even for a wrong key; reading sqlite_master validates decryption.
        await db.rawQuery('SELECT count(*) FROM sqlite_master');
        await onConfigure(db);
      },
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    ),
  );
}
