# POS & Accounts Pro v10 Core Engine Implementation Plan

## Phase 1: Core Business Engine

### Inventory Flow
- Sale decreases stock
- Purchase Receive increases stock
- Sale Return restores stock
- Purchase Return decreases stock

### Transaction Engine
All financial activities use a unified transaction flow:
- Sale
- Purchase
- Expense
- Payment
- Return

### Ledger Connections
Customer:
- Credit sales
- Payments
- Balance tracking

Supplier:
- Purchases
- Payments
- Outstanding balance

## Development Order

1. Core database migration
2. Stock movement engine
3. Transaction service
4. Sale integration
5. Purchase integration
6. Reports foundation

## Testing

Before release:
- Stock accuracy test
- Cash accuracy test
- Credit balance test
- Backup test
