import 'package:workmanager/workmanager.dart';
import 'cloud_backup_service.dart';

const qamvioDailyBackupTask='qamvioDailyBackup';

@pragma('vm:entry-point')
void cloudBackupDispatcher(){
  Workmanager().executeTask((task,inputData) async {
    try {
      await CloudBackupService.instance.backupNow();
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
    existingWorkPolicy:ExistingWorkPolicy.keep,
    constraints:Constraints(networkType:NetworkType.connected),
  );
}
