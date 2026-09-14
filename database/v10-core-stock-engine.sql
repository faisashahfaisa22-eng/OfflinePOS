-- POS & Accounts Pro v10 Core Stock Engine

CREATE TABLE stock_movements (
 id INTEGER PRIMARY KEY,
 product_id INTEGER NOT NULL,
 movement_type TEXT NOT NULL,
 quantity REAL NOT NULL,
 reference_type TEXT,
 reference_id INTEGER,
 note TEXT,
 created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Movement Types:
-- OPENING_STOCK
-- PURCHASE
-- SALE
-- SALE_RETURN
-- PURCHASE_RETURN
-- DAMAGE
-- ADJUSTMENT

CREATE TABLE transactions (
 id INTEGER PRIMARY KEY,
 business_id INTEGER NOT NULL,
 transaction_type TEXT NOT NULL,
 amount REAL NOT NULL,
 reference_type TEXT,
 reference_id INTEGER,
 created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
