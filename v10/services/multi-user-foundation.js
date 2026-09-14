// POS & Accounts Pro v10
// Multi User Foundation

const roles = {
  OWNER: ['all'],
  MANAGER: ['sales','purchase','inventory','reports'],
  CASHIER: ['sales','customer']
};

function hasPermission(role, action){
  return roles[role]?.includes('all') || roles[role]?.includes(action);
}
