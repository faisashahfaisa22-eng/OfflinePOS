import 'local_auth_service.dart';

/// Page access rules ported from QAMVIO v15 (allowedPagesForUser):
/// Admin -> everything. Cashier / Salesman -> sales invoice, fuel pump, stock,
/// customer statement and salesman statement only.
/// NOTE: This is UI-level access control on a single offline device. It stops
/// accidental use, but real protection of the data is the encrypted database.
enum AppPage { sales, products, purchases, customers, suppliers, salesmen, loans, expenses, fuel, pharmacy, reports, cloud, users }

class Permissions {
  Permissions._();

  static const _restricted={
    AppPage.sales,
    AppPage.products,
    AppPage.customers,
    AppPage.salesmen,
    AppPage.fuel,
  };

  static bool canOpen(AppPage page) {
    final user=LocalAuthService.instance.current;
    if(user==null||!user.active) return false;
    if(user.role==UserRole.admin) return true;
    return _restricted.contains(page);
  }
}
