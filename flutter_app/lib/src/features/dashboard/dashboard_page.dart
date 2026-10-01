import 'package:flutter/material.dart';
import '../../data/qamvio_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, num>> totals;
  @override
  void initState() { super.initState(); totals = QamvioDatabase.instance.dashboardTotals(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QAMVIO POS')),
      body: FutureBuilder<Map<String, num>>(
        future: totals,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final d = snapshot.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('QAMVIO Flutter Core', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Offline SQLite is the source of truth. Cloud synchronization is layered on top of local data.'),
            const SizedBox(height: 20),
            _tile('Sales', d['sales'] ?? 0), _tile('Expenses', d['expenses'] ?? 0),
            _tile('Products', d['products'] ?? 0), _tile('Customers', d['customers'] ?? 0),
          ]);
        },
      ),
    );
  }
  Widget _tile(String label, num value) => Card(child: ListTile(title: Text(label), trailing: Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold))));
}
