// POS & Accounts Pro v10.30
// Customer + Supplier Ledger Integration

export function updateCustomerBalance(customer, amount, type = 'debit') {
  return {
    customerId: customer.id,
    amount,
    type,
    updatedAt: new Date().toISOString()
  };
}

export function updateSupplierBalance(supplier, amount, type = 'credit') {
  return {
    supplierId: supplier.id,
    amount,
    type,
    updatedAt: new Date().toISOString()
  };
}

export function createLedgerEntry(account, transaction) {
  return {
    accountId: account.id,
    transactionId: transaction.id,
    amount: transaction.amount,
    date: new Date().toISOString()
  };
}

export function calculateDue(total, paid) {
  return Math.max(total - paid, 0);
}
