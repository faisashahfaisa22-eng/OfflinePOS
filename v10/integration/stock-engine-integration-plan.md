# POS & Accounts Pro v10.1 Stock Engine Integration

## Goal
Connect inventory movements with real business actions.

## Sale Flow
- Validate product quantity
- Create sale transaction
- Reduce stock
- Create stock movement record

## Purchase Receive Flow
- Receive supplier items
- Increase stock
- Update supplier balance
- Create purchase transaction

## Return Flow
- Customer return increases stock when applicable
- Supplier return decreases stock
- Adjust related balances

## Testing Cases
- Sale with available stock
- Sale exceeding stock
- Purchase receive update
- Product return
- Stock history verification
