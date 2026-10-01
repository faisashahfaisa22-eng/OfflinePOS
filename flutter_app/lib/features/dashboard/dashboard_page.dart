import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../products/products_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, num>> totals;

  void reload() => setState(() => totals = AppDatabase.instance.dashboardTotals());

  @override
  void initState() {
    super.initState();
    totals = AppDatabase.instance.dashboardTotals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QAMVIO POS')),
      drawer: QamvioDrawer(onReturn: reload),
      body: FutureBuilder<Map<String, num>>(
        future: totals,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const {
            'sales': 0, 'expenses': 0, 'products': 0, 'customers': 0, 'due': 0,
          };
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Business Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Native Flutter • SQLite offline-first'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    MetricCard('Sales', data['sales'] ?? 0, Icons.point_of_sale),
                    MetricCard('Expenses', data['expenses'] ?? 0, Icons.receipt_long),
                    MetricCard('Products', data['products'] ?? 0, Icons.inventory_2),
                    MetricCard('Customers', data['customers'] ?? 0, Icons.people),
                    MetricCard('Due', data['due'] ?? 0, Icons.account_balance_wallet),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storage),
                    title: const Text('SQLite Offline Database'),
                    subtitle: const Text('Products and business records are stored in the native app database.'),
                    trailing: const Icon(Icons.check_circle),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: const Text('Products & Inventory'),
                    subtitle: const Text('Open the first migrated native module'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsPage()));
                      reload();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final num value;
  final IconData icon;
  const MetricCard(this.label, this.value, this.icon, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 165,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon),
          const SizedBox(height: 12),
          Text(label),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      ),
    ),
  );
}

class QamvioDrawer extends StatelessWidget {
  final VoidCallback onReturn;
  const QamvioDrawer({required this.onReturn, super.key});

  @override
  Widget build(BuildContext context) => Drawer(
    child: ListView(children: [
      const DrawerHeader(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('QAMVIO POS', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
        Text('Flutter migration'),
      ])),
      const ListTile(leading: Icon(Icons.dashboard), title: Text('Dashboard')),
      ListTile(
        leading: const Icon(Icons.inventory_2),
        title: const Text('Products & Inventory'),
        onTap: () async {
          Navigator.pop(context);
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsPage()));
          onReturn();
        },
      ),
      const Divider(),
      const ListTile(leading: Icon(Icons.point_of_sale), title: Text('Sales & Invoice'), subtitle: Text('Migration next')),
      const ListTile(leading: Icon(Icons.people), title: Text('Customers'), subtitle: Text('Migration next')),
      const ListTile(leading: Icon(Icons.local_shipping), title: Text('Suppliers'), subtitle: Text('Migration next')),
      const ListTile(leading: Icon(Icons.receipt_long), title: Text('Expenses'), subtitle: Text('Migration next')),
      const ListTile(leading: Icon(Icons.local_gas_station), title: Text('Oil / Fuel Pump'), subtitle: Text('Schema ready')),
      const ListTile(leading: Icon(Icons.local_pharmacy), title: Text('Pharmacy'), subtitle: Text('Migration next')),
      const ListTile(leading: Icon(Icons.bar_chart), title: Text('Reports'), subtitle: Text('Migration next')),
      const ListTile(leading: Icon(Icons.cloud), title: Text('Cloud & Backup'), subtitle: Text('Sync queue prepared')),
    ]),
  );
}
