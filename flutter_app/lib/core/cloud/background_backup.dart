import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'cloud_backup_service.dart';
import 'cloud_config.dart';

const qamvioDailyBackupTask='qamvioDailyBackup';

/// Runs in a background isolate. The encrypted database cannot be opened here
/// (the key exists only after a user signs in), so the task uploads the encrypted
/// backup file that the app prepared while it was unlocked.
@pragma('vm:entry-point')
void cloudBackupDispatcher(){
  Workmanager().executeTask((task,inputData) async {
    try {
      // A fresh isolate has no Supabase instance; restore the saved session.
      await Supabase.initialize(url:CloudConfig.supabaseUrl,publishableKey:CloudConfig.supabaseAnonKey);
      await CloudBackupService.instance.uploadPendingFile();
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> scheduleDailyCloudBackup() async {
  await Workmanager().registerPeriodicTask(
    'qamvio-daily-cloud-backup',
    qamvioDailyBackupTask,
    frequency:const Duration(hours:24),
    existingWorkPolicy:ExistingPeriodicWorkPolicy.keep,
    constraints:Constraints(networkType:NetworkType.connected),
  );
}
