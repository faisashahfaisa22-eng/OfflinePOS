// POS & Accounts Pro v10
// Backup foundation

function createBackupQueue(data){
  return {
    status:'pending',
    createdAt:new Date().toISOString(),
    payload:data
  };
}

function markBackupComplete(item){
  item.status='completed';
  return item;
}
