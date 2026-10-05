import 'package:flutter/material.dart';
import 'core/app_language.dart';
import 'data/app_database.dart';
import 'features/products_page.dart';
import 'features/entity_pages.dart';
import 'features/sales_page.dart';
import 'features/purchases_page.dart';
import 'features/reports_page.dart';
import 'features/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const QamvioApp());
}

class QamvioApp extends StatelessWidget {
  const QamvioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'QAMVIO POS',
        locale: Locale(lang.language.name),
        builder: (context, child) => Directionality(
          textDirection: lang.direction,
          child: child ?? const SizedBox.shrink(),
        ),
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF174EA6),
        ),
        home: const DashboardPage(),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, num> totals = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    totals = await AppDatabase.instance.dashboardTotals();
    if (mounted) setState(() {});
  }

  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page))
          .then((_) => refresh());

  @override
  Widget build(BuildContext context) {
    final l = AppLanguageController.instance;
    final modules = <({IconData icon, String title, Widget page})>[
      (icon: Icons.point_of_sale, title: l.tr('sales_invoice'), page: const SalesPage()),
      (icon: Icons.inventory_2, title: l.tr('products_inventory'), page: const ProductsPage()),
      (icon: Icons.shopping_cart_checkout, title: l.tr('purchases'), page: const PurchasesPage()),
      (icon: Icons.people, title: l.tr('customers'), page: const EntityPage(kind: EntityKind.customers)),
      (icon: Icons.local_shipping, title: l.tr('suppliers'), page: const EntityPage(kind: EntityKind.suppliers)),
      (icon: Icons.payments, title: l.tr('expenses_accounts'), page: const EntityPage(kind: EntityKind.expenses)),
      (icon: Icons.local_gas_station, title: l.tr('oil_fuel'), page: const EntityPage(kind: EntityKind.fuelTanks)),
      (icon: Icons.medication, title: l.tr('pharmacy'), page: const ProductsPage()),
      (icon: Icons.assessment, title: l.tr('reports'), page: const ReportsPage()),
      (icon: Icons.settings, title: l.tr('settings'), page: const SettingsPage()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${l.tr('app_title')} — ${l.tr('dashboard')}'),
        actions: [
          PopupMenuButton<AppLang>(
            tooltip: l.tr('language'),
            icon: const Icon(Icons.language),
            onSelected: l.setLanguage,
            itemBuilder: (_) => [
              PopupMenuItem(value: AppLang.en, child: Text(l.tr('english'))),
              PopupMenuItem(value: AppLang.ps, child: Text(l.tr('pashto'))),
              PopupMenuItem(value: AppLang.fa, child: Text(l.tr('dari'))),
              PopupMenuItem(value: AppLang.ur, child: Text(l.tr('urdu'))),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                stat(l.tr('sales'), '${totals['sales'] ?? 0}'),
                stat(l.tr('products'), '${totals['products'] ?? 0}'),
                stat(l.tr('customers'), '${totals['customers'] ?? 0}'),
                stat(l.tr('revenue'), '${totals['revenue'] ?? 0}'),
                stat(l.tr('expenses'), '${totals['expenses'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 1.35,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: modules.length,
              itemBuilder: (_, i) {
                final item = modules[i];
                return Card(
                  child: InkWell(
                    onTap: () => open(item.page),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 34),
                        const SizedBox(height: 8),
                        Text(item.title, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget stat(String title, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(title),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      );
}
