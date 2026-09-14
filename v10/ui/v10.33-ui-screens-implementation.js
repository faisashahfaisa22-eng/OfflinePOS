// POS & Accounts Pro v10.33
// UI Screens Implementation Foundation

const Screens = {
  dashboard: {
    title: 'Dashboard',
    cards: ['Sales', 'Profit', 'Stock Alert', 'Customer Due', 'Supplier Payable']
  },
  products: {
    title: 'Products',
    actions: ['Add Product', 'Edit Product', 'Barcode Search', 'Stock View']
  },
  sales: {
    title: 'Sales',
    actions: ['New Sale', 'Barcode Scan', 'Payment', 'Invoice']
  },
  purchases: {
    title: 'Purchases',
    actions: ['Purchase Receive', 'Supplier Select', 'Stock Update']
  },
  customers: {
    title: 'Customers',
    actions: ['Ledger', 'Payment', 'Due Reminder']
  },
  suppliers: {
    title: 'Suppliers',
    actions: ['Ledger', 'Payment', 'Purchase History']
  }
};

function loadScreen(name) {
  return Screens[name] || null;
}

module.exports = { Screens, loadScreen };
