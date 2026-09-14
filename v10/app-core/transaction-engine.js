// POS & Accounts Pro v10.28
// Transaction Engine Core

export class TransactionEngine {
  constructor(db) {
    this.db = db;
  }

  createTransaction(data) {
    const transaction = {
      id: Date.now(),
      type: data.type,
      amount: data.amount,
      customerId: data.customerId || null,
      supplierId: data.supplierId || null,
      createdAt: new Date().toISOString()
    };

    this.db.transactions.push(transaction);
    return transaction;
  }

  customerPayment(customerId, amount) {
    return this.createTransaction({
      type: 'CUSTOMER_PAYMENT',
      customerId,
      amount
    });
  }

  supplierPayment(supplierId, amount) {
    return this.createTransaction({
      type: 'SUPPLIER_PAYMENT',
      supplierId,
      amount
    });
  }

  expense(category, amount) {
    return this.createTransaction({
      type: 'EXPENSE',
      category,
      amount
    });
  }
}
