import 'package:flutter/material.dart';
import 'core/database/app_database.dart';
import 'features/dashboard/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const QamvioApp());
}

class QamvioApp extends StatelessWidget {
  const QamvioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QAMVIO POS',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF174EA6),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      ),
      home: const DashboardPage(),
    );
  }
}
