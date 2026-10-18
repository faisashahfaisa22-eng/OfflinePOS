import 'package:flutter/material.dart';
import '../../data/app_database.dart';
import '../products/products_page.dart';
import '../customers/customers_page.dart';
import '../expenses/expenses_page.dart';
import '../sales/sales_page.dart';

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
            _NavTile(icon: Icons.point_of_sale, title: 'Sales', page: SalesPage()),
            _NavTile(icon: Icons.inventory_2, title: 'Products', page: ProductsPage()),
            _NavTile(icon: Icons.people, title: 'Customers', page: CustomersPage()),
            ListTile(leading: Icon(Icons.local_shipping), title: Text('Suppliers')),
            _NavTile(icon: Icons.payments, title: 'Expenses', page: ExpensesPage()),
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

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.page});
  final IconData icon;
  final String title;
  final Widget page;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    },
  );
}
