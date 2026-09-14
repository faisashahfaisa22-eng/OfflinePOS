// POS & Accounts Pro v10.32
// Dashboard UI + Reports Screen Integration Foundation

export const dashboard = {
  sales: 0,
  profit: 0,
  stockAlerts: [],
  customerDue: 0,
  supplierPayable: 0
};

export function updateDashboard(data) {
  dashboard.sales = data.sales || 0;
  dashboard.profit = data.profit || 0;
  dashboard.stockAlerts = data.stockAlerts || [];
  dashboard.customerDue = data.customerDue || 0;
  dashboard.supplierPayable = data.supplierPayable || 0;
  return dashboard;
}

export function getDashboardCards() {
  return [
    { title: 'Today Sales', value: dashboard.sales },
    { title: 'Profit', value: dashboard.profit },
    { title: 'Customer Due', value: dashboard.customerDue },
    { title: 'Supplier Payable', value: dashboard.supplierPayable }
  ];
}

export function getStockAlerts() {
  return dashboard.stockAlerts;
}
