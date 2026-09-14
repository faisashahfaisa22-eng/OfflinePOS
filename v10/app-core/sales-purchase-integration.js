// POS & Accounts Pro v10.29
// Sales + Purchase Integration Core

function processSale(product, qty, price, paymentType) {
  if (product.stock < qty) throw new Error('Insufficient stock');

  product.stock -= qty;

  return {
    type: 'SALE',
    productId: product.id,
    quantity: qty,
    total: qty * price,
    paymentType,
    createdAt: new Date().toISOString()
  };
}

function receivePurchase(product, qty, cost, supplierId) {
  product.stock += qty;

  return {
    type: 'PURCHASE',
    productId: product.id,
    quantity: qty,
    totalCost: qty * cost,
    supplierId,
    createdAt: new Date().toISOString()
  };
}

module.exports = { processSale, receivePurchase };
