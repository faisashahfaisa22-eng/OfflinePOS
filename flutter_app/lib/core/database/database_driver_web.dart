// ignore_for_file: implementation_imports, deprecated_member_use

import 'dart:async';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/src/sqflite_ffi_impl.dart' as ffi_impl;
import 'package:sqflite_common_ffi/src/sqflite_import.dart'
    show FfiMethodCall, buildDatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show SqfliteFfiWebOptions;
import 'package:sqflite_common_ffi_web/src/database_factory_web.dart'
    show ffiMethodCallHandleNoWebWorker;
import 'package:sqflite_common_ffi_web/src/sqflite_ffi_impl_web.dart'
    show SqfliteFfiHandlerWeb;
import 'package:sqflite_common_ffi_web/src/web/load_sqlite_web.dart'
    show SqfliteFfiWebContextImpl, sqfliteFfiWebLoadSqlite3Wasm;
import 'package:sqlite3/wasm.dart' show InMemoryFileSystem;

import 'web_encrypted_store.dart';

const _databaseName = 'qamvio_pos.db';

DatabaseFactory? _factory;
Future<DatabaseFactory>? _factoryFuture;
Future<void>? _restoreFuture;

Future<DatabaseFactory> _getFactory() {
  final ready = _factory;
  if (ready != null) return Future.value(ready);
  return _factoryFuture ??= _createEncryptedMemoryFactory();
}

Future<DatabaseFactory> _createEncryptedMemoryFactory() async {
  final options = SqfliteFfiWebOptions(
    sqlite3WasmUri: Uri.parse('sqlite3mc.wasm'),
  );

  // SQLite3MC can encrypt its normal file VFS, but the IndexedDB VFS used by
  // sqflite_common_ffi_web does not implement the codec hooks. Keep the SQLite
  // file in an in-memory VFS, where SQLite3MC encryption is supported, and
  // persist the already-encrypted file bytes separately in IndexedDB.
  final fs = InMemoryFileSystem(name: 'qamvio-encrypted-memory');
  final seed = SqfliteFfiWebContextImpl(options: options, fs: fs);
  final context = await sqfliteFfiWebLoadSqlite3Wasm(
    options,
    context: seed,
  );

  ffi_impl.sqfliteFfiHandler = SqfliteFfiHandlerWeb(context);

  final factory = buildDatabaseFactory(
    tag: 'qamvio_encrypted_web',
    invokeMethod: (String method, [Object? arguments]) {
      return ffiMethodCallHandleNoWebWorker(
        FfiMethodCall(method, arguments),
        context,
      );
    },
  );

  _factory = factory;
  return factory;
}

Future<void> _ensureRestored() {
  return _restoreFuture ??= () async {
    final factory = await _getFactory();
    final bytes = await loadEncryptedDatabaseBytes();
    if (bytes != null && bytes.isNotEmpty) {
      await factory.writeDatabaseBytes(_databaseName, bytes);
    }
  }();
}

Future<void> _persistDatabaseBytes() async {
  final factory = await _getFactory();
  if (!await factory.databaseExists(_databaseName)) return;

  final bytes = await factory.readDatabaseBytes(_databaseName);
  if (bytes.isNotEmpty) {
    await saveEncryptedDatabaseBytes(bytes);
  }
}

Future<void> deleteQamvioDatabase() async {
  await _ensureRestored();
  final factory = await _getFactory();

  if (await factory.databaseExists(_databaseName)) {
    await factory.deleteDatabase(_databaseName);
  }
  await deleteEncryptedDatabaseBytes();
}

/// Opens QAMVIO's browser database with SQLite3 Multiple Ciphers.
///
/// The database itself lives in an in-memory SQLite VFS so SQLite3MC can apply
/// page encryption. Only the resulting encrypted SQLite file bytes are copied
/// to IndexedDB for persistence across browser restarts.
Future<Database> openQamvioDatabase({
  required String keyHex,
  required int version,
  required Future<void> Function(Database db) onConfigure,
  required Future<void> Function(Database db, int version) onCreate,
  required Future<void> Function(Database db, int oldVersion, int newVersion)
      onUpgrade,
}) async {
  await _ensureRestored();
  final factory = await _getFactory();

  final inner = await factory.openDatabase(
    _databaseName,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) async {
        await db.execute("PRAGMA cipher = 'chacha20'");
        await db.execute("PRAGMA key = 'raw:$keyHex'");

        // PRAGMA key itself may succeed for a wrong key. Reading sqlite_master
        // forces authenticated decryption and therefore rejects the wrong DEK.
        await db.rawQuery('SELECT count(*) FROM sqlite_master');
        await onConfigure(db);
      },
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    ),
  );

  // Persist schema creation / migration immediately before returning.
  await _persistDatabaseBytes();
  return _PersistingDatabase(inner, _persistDatabaseBytes);
}

class _PersistingDatabase implements Database {
  _PersistingDatabase(this._inner, this._persist);

  final Database _inner;
  final Future<void> Function() _persist;

  @override
  Database get database => this;

  @override
  String get path => _inner.path;

  @override
  bool get isOpen => _inner.isOpen;

  @override
  Future<void> close() async {
    if (!_inner.isOpen) return;
    await _inner.close();
    await _persist();
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    final result = await action();
    await _persist();
    return result;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _write(() => _inner.execute(sql, arguments));

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _write(() => _inner.rawInsert(sql, arguments));

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _write(
        () => _inner.insert(
          table,
          values,
          nullColumnHack: nullColumnHack,
          conflictAlgorithm: conflictAlgorithm,
        ),
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _write(() => _inner.rawUpdate(sql, arguments));

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _write(
        () => _inner.update(
          table,
          values,
          where: where,
          whereArgs: whereArgs,
          conflictAlgorithm: conflictAlgorithm,
        ),
      );

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _write(() => _inner.rawDelete(sql, arguments));

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _write(
        () => _inner.delete(
          table,
          where: where,
          whereArgs: whereArgs,
        ),
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _inner.rawQuery(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _inner.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _inner.rawQueryCursor(
        sql,
        arguments,
        bufferSize: bufferSize,
      );

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      _inner.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Batch batch() => _PersistingBatch(_inner.batch(), _persist);

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    var dirty = false;
    final result = await _inner.transaction<T>(
      (txn) => action(
        _PersistingTransaction(
          txn,
          this,
          () {
            dirty = true;
          },
        ),
      ),
      exclusive: exclusive,
    );
    if (dirty) await _persist();
    return result;
  }

  @override
  Future<T> readTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    var dirty = false;
    final result = await _inner.readTransaction<T>(
      (txn) => action(
        _PersistingTransaction(
          txn,
          this,
          () {
            dirty = true;
          },
        ),
      ),
    );
    if (dirty) await _persist();
    return result;
  }

  @override
  Future<T> devInvokeMethod<T>(
    String method, [
    Object? arguments,
  ]) =>
      _inner.devInvokeMethod<T>(method, arguments);

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _inner.devInvokeSqlMethod<T>(method, sql, arguments);
}

class _PersistingTransaction implements Transaction {
  _PersistingTransaction(this._inner, this._database, this._markDirty);

  final Transaction _inner;
  final Database _database;
  final void Function() _markDirty;

  @override
  Database get database => _database;

  void _dirty() => _markDirty();

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _inner.execute(sql, arguments);
    _dirty();
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final result = await _inner.rawInsert(sql, arguments);
    _dirty();
    return result;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final result = await _inner.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    _dirty();
    return result;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final result = await _inner.rawUpdate(sql, arguments);
    _dirty();
    return result;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final result = await _inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    _dirty();
    return result;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final result = await _inner.rawDelete(sql, arguments);
    _dirty();
    return result;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final result = await _inner.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    _dirty();
    return result;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _inner.rawQuery(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _inner.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _inner.rawQueryCursor(
        sql,
        arguments,
        bufferSize: bufferSize,
      );

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      _inner.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Batch batch() => _PersistingBatch(
        _inner.batch(),
        () async {
          _dirty();
        },
      );
}

class _PersistingBatch implements Batch {
  _PersistingBatch(this._inner, this._afterWrite);

  final Batch _inner;
  final Future<void> Function() _afterWrite;
  bool _dirty = false;

  void _markDirty() {
    _dirty = true;
  }

  Future<List<Object?>> _finish(
    Future<List<Object?>> Function() action,
  ) async {
    final result = await action();
    if (_dirty) await _afterWrite();
    return result;
  }

  @override
  int get length => _inner.length;

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _inner.execute(sql, arguments);
    _markDirty();
  }

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _inner.rawInsert(sql, arguments);
    _markDirty();
  }

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _inner.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    _markDirty();
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _inner.rawUpdate(sql, arguments);
    _markDirty();
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    _markDirty();
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _inner.rawDelete(sql, arguments);
    _markDirty();
  }

  @override
  void delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    _inner.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    _markDirty();
  }

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    _inner.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {
    _inner.rawQuery(sql, arguments);
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) =>
      _finish(
        () => _inner.commit(
          exclusive: exclusive,
          noResult: noResult,
          continueOnError: continueOnError,
        ),
      );

  @override
  Future<List<Object?>> apply({
    bool? noResult,
    bool? continueOnError,
  }) =>
      _finish(
        () => _inner.apply(
          noResult: noResult,
          continueOnError: continueOnError,
        ),
      );
}
