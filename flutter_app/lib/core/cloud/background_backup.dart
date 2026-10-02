import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'cloud_backup_service.dart';
import 'cloud_config.dart';

const qamvioDailyBackupTask = 'qamvioDailyBackup';

/// Runs in a background isolate. The encrypted database cannot be opened here
/// (the key exists only after a user signs in), so the task uploads the
/// encrypted backup file that the app prepared while it was unlocked.
///
/// The cloud session must have been established from the main app before a
/// background upload can succeed.
@pragma('vm:entry-point')
void cloudBackupDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Some Android builds/OEM ROMs need an explicit Flutter binding before
      // plugins are used from a fresh background isolate.
      WidgetsFlutterBinding.ensureInitialized();

      // A fresh isolate has no Supabase instance; initialize it before using
      // CloudBackupService. Session restoration is handled by supabase_flutter.
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        publishableKey: CloudConfig.supabaseAnonKey,
      );

      await CloudBackupService.instance.uploadPendingFile();
      return true;
    } catch (e, st) {
      debugPrint('Background cloud backup failed: $e\n$st');
      return false;
    }
  });
}

Future<void> scheduleDailyCloudBackup() async {
  await Workmanager().registerPeriodicTask(
    'qamvio-daily-cloud-backup',
    qamvioDailyBackupTask,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
}
