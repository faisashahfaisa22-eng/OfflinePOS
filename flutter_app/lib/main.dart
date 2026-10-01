import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/cloud/background_backup.dart';
import 'core/cloud/cloud_config.dart';
import 'core/database/app_database.dart';
import 'core/localization/language_controller.dart';
import 'features/auth/login_page.dart';
import 'features/migration/legacy_migration_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable();
  await Supabase.initialize(url:CloudConfig.supabaseUrl,publishableKey:CloudConfig.supabaseAnonKey);
  await Workmanager().initialize(cloudBackupDispatcher);
  await scheduleDailyCloudBackup();
  await AppDatabase.instance.database;
  await LanguageController.instance.load();
  runApp(const QamvioApp());
}

class QamvioApp extends StatelessWidget {
  const QamvioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller=LanguageController.instance;
    return ListenableBuilder(
      listenable:controller,
      builder:(context,_){
        final s=controller.strings;
        return MaterialApp(
          debugShowCheckedModeBanner:false,
          title:'QAMVIO POS',
          builder:(context,child)=>Directionality(textDirection:s.direction,child:child??const SizedBox.shrink()),
          theme:ThemeData(
            useMaterial3:true,
            colorSchemeSeed:const Color(0xFF174EA6),
            scaffoldBackgroundColor:const Color(0xFFF6F8FC),
            inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder()),
          ),
          home:StreamBuilder<AuthState>(
            stream:Supabase.instance.client.auth.onAuthStateChange,
            builder:(context,snapshot){
              return Supabase.instance.client.auth.currentSession==null
                ? const LoginPage()
                : const LegacyMigrationGate();
            },
          ),
        );
      },
    );
  }
}
