import 'package:flutter/material.dart';
import 'data/app_database.dart';
import 'features/dashboard/dashboard_page.dart';

class QamvioApp extends StatefulWidget {
  const QamvioApp({super.key});
  @override
  State<QamvioApp> createState() => _QamvioAppState();
}

class _QamvioAppState extends State<QamvioApp> {
  @override
  void initState() {
    super.initState();
    AppDatabase.instance.database;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QAMVIO POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF174EA6)),
      home: const DashboardPage(),
    );
  }
}
