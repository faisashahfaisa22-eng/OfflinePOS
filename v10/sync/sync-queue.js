// POS & Accounts Pro v10
// Offline Sync Queue Foundation

function addToSyncQueue(record) {
  return {
    ...record,
    status: 'pending',
    createdAt: new Date().toISOString()
  };
}

module.exports = { addToSyncQueue };
