import 'package:shared_preferences/shared_preferences.dart';

const _pendingKey = 'qamvio_pending_encrypted_backup_v16';

Future<void> writePendingBackup(String json) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingKey, json);
}

Future<String?> readPendingBackup() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_pendingKey);
}

Future<void> deletePendingBackup() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_pendingKey);
}
