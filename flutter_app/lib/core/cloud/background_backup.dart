import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'cloud_backup_service.dart';
import 'cloud_config.dart';

const qamvioDailyBackupTask = 'qamvioDailyBackup';

/// Runs in a background isolate. The encrypted database cannot be opened here
/// because the database key is only available after a local user signs in.
///
/// Instead, the task uploads the encrypted backup file that QAMVIO prepared
/// while the app was unlocked. A cloud account must already have been signed in
/// from Cloud & Backup so Supabase can restore its persisted session.
@pragma('vm:entry-point')
void cloudBackupDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Background tasks run in a fresh isolate. Initialize Flutter bindings
      // before using plugins on Android/OEM builds that require them.
      WidgetsFlutterBinding.ensureInitialized();

      // A fresh isolate has no Supabase singleton yet. Re-create it using the
      // same project configuration; supabase_flutter restores persisted auth.
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        publishableKey: CloudConfig.supabaseAnonKey,
      );

      await CloudBackupService.instance.uploadPendingFile();
      return true;
    } catch (_) {
      // Returning false lets Workmanager treat the execution as unsuccessful
      // without crashing or blocking the offline-first app.
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
