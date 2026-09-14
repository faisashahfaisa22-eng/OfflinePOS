// POS & Accounts Pro v10
// Transaction Engine Foundation

function createTransaction(type, amount, reference) {
  return {
    type,
    amount,
    reference,
    createdAt: new Date().toISOString()
  };
}

module.exports = { createTransaction };
