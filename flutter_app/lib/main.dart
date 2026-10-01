import 'package:flutter/material.dart';
import 'data/app_database.dart';

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF174EA6)),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const modules = <(IconData, String)>[
    (Icons.point_of_sale, 'Sales & Invoice'),
    (Icons.inventory_2, 'Products & Inventory'),
    (Icons.people, 'Customers'),
    (Icons.local_shipping, 'Suppliers'),
    (Icons.payments, 'Expenses & Accounts'),
    (Icons.badge, 'Salesmen'),
    (Icons.local_gas_station, 'Oil / Fuel Pump'),
    (Icons.medication, 'Pharmacy'),
    (Icons.assessment, 'Reports'),
    (Icons.cloud_sync, 'Cloud Backup & Restore'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QAMVIO POS')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220, childAspectRatio: 1.35,
          crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: modules.length,
        itemBuilder: (context, i) {
          final item = modules[i];
          return Card(
            child: InkWell(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.$2} migration in progress'))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(item.$1, size: 34),
                  const SizedBox(height: 10),
                  Text(item.$2, textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
