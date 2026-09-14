-- POS & Accounts Pro v10 Core Database Foundation

CREATE TABLE businesses (
 id INTEGER PRIMARY KEY,
 name TEXT,
 type TEXT,
 currency TEXT,
 created_at DATETIME
);

CREATE TABLE products (
 id INTEGER PRIMARY KEY,
 business_id INTEGER,
 category_id INTEGER,
 name TEXT,
 barcode TEXT,
 purchase_price REAL,
 sale_price REAL,
 quantity REAL,
 minimum_stock REAL,
 created_at DATETIME
);

CREATE TABLE stock_movements (
 id INTEGER PRIMARY KEY,
 product_id INTEGER,
 type TEXT,
 quantity REAL,
 reference_type TEXT,
 reference_id INTEGER,
 created_at DATETIME
);

CREATE TABLE transactions (
 id INTEGER PRIMARY KEY,
 business_id INTEGER,
 type TEXT,
 amount REAL,
 reference_type TEXT,
 reference_id INTEGER,
 created_at DATETIME
);

CREATE TABLE customers (
 id INTEGER PRIMARY KEY,
 business_id INTEGER,
 name TEXT,
 phone TEXT,
 balance REAL DEFAULT 0
);

CREATE TABLE suppliers (
 id INTEGER PRIMARY KEY,
 business_id INTEGER,
 name TEXT,
 phone TEXT,
 balance REAL DEFAULT 0
);

CREATE TABLE expenses (
 id INTEGER PRIMARY KEY,
 business_id INTEGER,
 amount REAL,
 category TEXT,
 created_at DATETIME
);
