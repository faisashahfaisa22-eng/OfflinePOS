// POS & Accounts Pro v10
// Core Stock Engine

function applyStockMovement(product, type, quantity) {
  const movement = {
    productId: product.id,
    type: type,
    quantity: quantity,
    date: new Date().toISOString()
  };

  if (type === 'SALE') product.quantity -= quantity;
  if (type === 'PURCHASE') product.quantity += quantity;
  if (type === 'SALE_RETURN') product.quantity += quantity;
  if (type === 'PURCHASE_RETURN') product.quantity -= quantity;

  return movement;
}

module.exports = { applyStockMovement };
