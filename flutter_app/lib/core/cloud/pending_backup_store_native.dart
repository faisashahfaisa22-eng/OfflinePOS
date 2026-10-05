import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

const _pendingFile = 'pending_backup.json';

Future<String> _pendingPath() async =>
    join(await getDatabasesPath(), _pendingFile);

Future<void> writePendingBackup(String json) async {
  final path = await _pendingPath();
  final temp = File('$path.tmp');
  await temp.writeAsString(json, flush: true);

  final target = File(path);
  if (await target.exists()) {
    await target.delete();
  }
  await temp.rename(path);
}

Future<String?> readPendingBackup() async {
  final file = File(await _pendingPath());
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> deletePendingBackup() async {
  final file = File(await _pendingPath());
  if (await file.exists()) {
    await file.delete();
  }
}
