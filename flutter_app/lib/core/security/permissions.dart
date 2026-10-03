import 'local_auth_service.dart';

/// v15 page access rules.
/// Admin -> every section.
/// Cashier / Salesman -> exactly the six sections exposed by v15:
/// Sales / Cash Report, model-specific Fuel/Pharmacy access, Stock, Stock Ledger,
/// Customer Statement and Salesman Statement.
enum AppPage {
  dashboard,
  quickSearch,
  saleInvoice,
  fuelPump,
  pharmacy,
  stock,
  stockLedger,
  products,
  purchases,
  discounts,
  salesmen,
  customers,
  customerLoans,
  customerStatement,
  suppliers,
  supplierStatement,
  expenses,
  salesmanLoans,
  salesmanStatement,
  capital,
  dailyClosing,
  cashBook,
  reports,
  recycleBin,
  deleteEntry,
  safetyCenter,
  userManagement,
  backup,
}

class Permissions {
  Permissions._();

  static const _v15Restricted={
    AppPage.saleInvoice,
    AppPage.fuelPump,
    AppPage.pharmacy,
    AppPage.stock,
    AppPage.stockLedger,
    AppPage.customerStatement,
    AppPage.salesmanStatement,
  };

  static bool canOpen(AppPage page) {
    final user=LocalAuthService.instance.current;
    if(user==null||!user.active) return false;
    if(user.role==UserRole.admin) return true;
    return _v15Restricted.contains(page);
  }

  static List<AppPage> visiblePages() {
    final user=LocalAuthService.instance.current;
    if(user==null||!user.active) return const [];
    if(user.role==UserRole.admin) return AppPage.values;
    return _v15Restricted.toList(growable:false);
  }
}
