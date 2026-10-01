import 'package:flutter/material.dart';
import 'core/database/app_database.dart';
import 'core/localization/language_controller.dart';
import 'features/dashboard/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  await LanguageController.instance.load();
  runApp(const QamvioApp());
}

class QamvioApp extends StatelessWidget {
  const QamvioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LanguageController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.strings;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'QAMVIO POS',
          builder: (context, child) => Directionality(
            textDirection: s.direction,
            child: child ?? const SizedBox.shrink(),
          ),
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF174EA6),
            scaffoldBackgroundColor: const Color(0xFFF6F8FC),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),
          home: const DashboardPage(),
        );
      },
    );
  }
}
