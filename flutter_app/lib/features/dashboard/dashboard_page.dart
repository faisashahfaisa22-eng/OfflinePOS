import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, num>> totals;
  @override
  void initState() { super.initState(); totals = AppDatabase.instance.dashboardTotals(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QAMVIO POS')),
      drawer: const _QamvioDrawer(),
      body: FutureBuilder<Map<String, num>>(
        future: totals,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const {'sales': 0, 'expenses': 0, 'products': 0};
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Offline-first Business Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Card('Sales', data['sales'] ?? 0),
            _Card('Expenses', data['expenses'] ?? 0),
            _Card('Products', data['products'] ?? 0),
            const SizedBox(height: 16),
            const Card(child: ListTile(leading: Icon(Icons.storage), title: Text('SQLite Offline Database'), subtitle: Text('Native database core is active.'))),
          ]);
        },
      ),
    );
  }
}
class _Card extends StatelessWidget {
  final String label; final num value;
  const _Card(this.label, this.value);
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 18)), Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))])));
}
class _QamvioDrawer extends StatelessWidget {
  const _QamvioDrawer();
  @override
  Widget build(BuildContext context) => Drawer(child: ListView(children: const [
    DrawerHeader(child: Text('QAMVIO POS', style: TextStyle(fontSize: 26))),
    ListTile(leading: Icon(Icons.dashboard), title: Text('Dashboard')),
    ListTile(leading: Icon(Icons.point_of_sale), title: Text('Sales & Invoice')),
    ListTile(leading: Icon(Icons.inventory_2), title: Text('Products & Inventory')),
    ListTile(leading: Icon(Icons.people), title: Text('Customers')),
    ListTile(leading: Icon(Icons.local_shipping), title: Text('Suppliers')),
    ListTile(leading: Icon(Icons.receipt_long), title: Text('Expenses')),
    ListTile(leading: Icon(Icons.local_gas_station), title: Text('Oil / Fuel Pump')),
    ListTile(leading: Icon(Icons.local_pharmacy), title: Text('Pharmacy')),
    ListTile(leading: Icon(Icons.bar_chart), title: Text('Reports')),
    ListTile(leading: Icon(Icons.cloud), title: Text('Cloud & Backup')),
  ]));
}
