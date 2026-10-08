import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';

import '../../core/business/business_model_controller.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/security/permissions.dart';
import '../../core/ui/qamvio_ui.dart';
import '../fuel/fuel_page.dart';
import '../pharmacy/pharmacy_page.dart';
import '../sales/sales_page.dart';
import '../v15/quick_stock_pages.dart';
import '../v15/statement_pages.dart';

/// v15 restricted landing for Cashier / Salesman.
/// Their visible sections are exactly:
/// Sales / Cash Report, Fuel / Oil Pump, Stock, Stock Ledger,
/// Customer Statement and Salesman Statement.
class RoleHomePage extends StatelessWidget {
  const RoleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = LocalAuthService.instance.current;
    final model = BusinessModelController.instance.type;

    // A Salesman login without a linked salesman record would open pages that
    // cannot be scoped to that salesman. Show a clear message instead.
    if (user?.role == UserRole.salesman &&
        (user?.salesmanId.isEmpty ?? true)) {
      return Scaffold(
        appBar: AppBar(
          title: Text('QAMVIO • ${BusinessModelController.instance.label}'),
          actions: [
            IconButton(
              tooltip:tr('Lock / Logout'),
              onPressed: () => LocalAuthService.instance.logout(),
              icon: const Icon(Icons.lock_outline_rounded),
            ),
          ],
        ),
        body: const QamvioEmptyState(
          icon: Icons.link_off_rounded,
          title: 'Account not linked',
          subtitle:
              'This Salesman login is not linked to a Salesman record. '
              'Ask the Admin to link it from Users / Login.',
        ),
      );
    }

    final items = <(AppPage, IconData, String, Widget)>[
      (
        AppPage.saleInvoice,
        Icons.point_of_sale_rounded,
        'Sales / Cash Report',
        const SalesPage(),
      ),
      if (model == BusinessModelType.fuelStation)
        (
          AppPage.fuelPump,
          Icons.local_gas_station_rounded,
          'Fuel / Oil Pump',
          const FuelPage(),
        ),
      if (model == BusinessModelType.pharmacy)
        (
          AppPage.pharmacy,
          Icons.local_pharmacy_rounded,
          'Pharmacy',
          const PharmacyPage(),
        ),
      (
        AppPage.stock,
        Icons.inventory_2_rounded,
        'Stock',
        const StockPage(),
      ),
      (
        AppPage.stockLedger,
        Icons.format_list_numbered_rounded,
        'Stock Ledger',
        const StockLedgerPage(),
      ),
      (
        AppPage.customerStatement,
        Icons.receipt_long_rounded,
        'Customer Statement',
        const CustomerStatementPage(),
      ),
      (
        AppPage.salesmanStatement,
        Icons.assignment_ind_rounded,
        'Salesman Statement',
        const SalesmanStatementPage(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FB),
      appBar: AppBar(
        title: Text('QAMVIO • ${BusinessModelController.instance.label}'),
        actions: [
          IconButton(
            tooltip:tr('Lock / Logout'),
            onPressed: () => LocalAuthService.instance.logout(),
            icon: const Icon(Icons.lock_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: QamvioUi.pagePadding,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF3730A3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QAMVIO POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SIGNED IN • ${user?.loginId ?? ''} • ${user?.role.label ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${BusinessModelController.instance.label} • ${tr('restricted role')}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final it in items.where((e) => Permissions.canOpen(e.$1)))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(it.$2, color: const Color(0xFF4F46E5)),
                title: Text(
                  it.$3,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => it.$4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
