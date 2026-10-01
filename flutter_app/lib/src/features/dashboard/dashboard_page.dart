import 'package:flutter/material.dart';
import '../../data/app_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, num>> totals;
  @override
  void initState() {
    super.initState();
    totals = AppDatabase.instance.dashboardTotals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QAMVIO POS')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(child: Text('QAMVIO POS')),
            ListTile(leading: Icon(Icons.point_of_sale), title: Text('Sales')),
            ListTile(leading: Icon(Icons.inventory_2), title: Text('Products')),
            ListTile(leading: Icon(Icons.people), title: Text('Customers')),
            ListTile(leading: Icon(Icons.local_shipping), title: Text('Suppliers')),
            ListTile(leading: Icon(Icons.payments), title: Text('Expenses')),
            ListTile(leading: Icon(Icons.local_gas_station), title: Text('Oil / Fuel Pump')),
            ListTile(leading: Icon(Icons.medication), title: Text('Pharmacy')),
            ListTile(leading: Icon(Icons.assessment), title: Text('Reports')),
            ListTile(leading: Icon(Icons.cloud_sync), title: Text('Cloud & Backup')),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, num>>(
        future: totals,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _Card('Sales', d['sales'] ?? 0, Icons.receipt_long),
              _Card('Products', d['products'] ?? 0, Icons.inventory_2),
              _Card('Customers', d['customers'] ?? 0, Icons.people),
              _Card('Expenses', d['expenses'] ?? 0, Icons.payments),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.value, this.icon);
  final String label;
  final num value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          ]),
        ),
      );
}
