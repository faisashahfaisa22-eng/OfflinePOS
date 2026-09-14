// POS & Accounts Pro v10.28
// Stock Engine Core

export class StockEngine {
  constructor(db) {
    this.db = db;
  }

  checkStock(productId, qty) {
    const product = this.db.products.find(p => p.id === productId);
    return product && product.quantity >= qty;
  }

  reduceStock(productId, qty) {
    const product = this.db.products.find(p => p.id === productId);
    if (!product || product.quantity < qty) {
      throw new Error('Insufficient stock');
    }
    product.quantity -= qty;
    this.recordMovement(productId, 'SALE', -qty);
  }

  increaseStock(productId, qty) {
    const product = this.db.products.find(p => p.id === productId);
    if (!product) throw new Error('Product not found');
    product.quantity += qty;
    this.recordMovement(productId, 'PURCHASE', qty);
  }

  adjustReturn(productId, qty) {
    this.increaseStock(productId, qty);
    this.recordMovement(productId, 'RETURN', qty);
  }

  recordMovement(productId, type, quantity) {
    this.db.stockMovements.push({
      productId,
      type,
      quantity,
      createdAt: new Date().toISOString()
    });
  }
}
