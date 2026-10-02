import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/cloud/background_backup.dart';
import 'core/cloud/cloud_backup_service.dart';
import 'core/cloud/cloud_config.dart';
import 'core/localization/language_controller.dart';
import 'core/security/local_auth_service.dart';
import 'core/ui/qamvio_ui.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/role_home_page.dart';
import 'features/migration/legacy_migration_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase is used ONLY as a cloud-backup destination. Login is local/offline.
  await Supabase.initialize(url:CloudConfig.supabaseUrl,publishableKey:CloudConfig.supabaseAnonKey);
  await Workmanager().initialize(cloudBackupDispatcher);
  await scheduleDailyCloudBackup();
  await LocalAuthService.instance.load();
  await LanguageController.instance.load();
  runApp(const QamvioApp());
}

class QamvioApp extends StatefulWidget {
  const QamvioApp({super.key});

  @override
  State<QamvioApp> createState()=>_QamvioAppState();
}

class _QamvioAppState extends State<QamvioApp> with WidgetsBindingObserver {
  /// Locks the app (and closes the encrypted database) after this long in the background.
  static const autoLockAfter=Duration(minutes:5);
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth=LocalAuthService.instance;
    if(state==AppLifecycleState.paused) {
      _pausedAt=DateTime.now();
      // Refresh the encrypted backup file while the key is still in memory.
      if(auth.unlocked) CloudBackupService.instance.prepareBackupFile().catchError((_){});
    } else if(state==AppLifecycleState.resumed) {
      final at=_pausedAt;
      _pausedAt=null;
      if(auth.unlocked&&at!=null&&DateTime.now().difference(at)>autoLockAfter) {
        auth.logout();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller=LanguageController.instance;
    return ListenableBuilder(
      listenable:Listenable.merge([controller,LocalAuthService.instance]),
      builder:(context,_){
        final s=controller.strings;
        final auth=LocalAuthService.instance;
        return MaterialApp(
          debugShowCheckedModeBanner:false,
          title:'QAMVIO POS',
          builder:(context,child)=>Directionality(textDirection:s.direction,child:child??const SizedBox.shrink()),
          theme:QamvioUi.theme(),
          darkTheme:QamvioUi.darkTheme(),
          themeMode:ThemeMode.system,
          home:!auth.unlocked
            ? const LoginPage()
            : auth.isAdmin
              ? const LegacyMigrationGate()
              : const RoleHomePage(),
        );
      },
    );
  }
}
