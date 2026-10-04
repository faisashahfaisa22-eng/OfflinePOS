import 'package:flutter/material.dart';
import 'features/dashboard/dashboard_page.dart';

class QamvioApp extends StatelessWidget {
  const QamvioApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QAMVIO POS',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF174EA6)),
      home: const DashboardPage(),
    );
  }
}
