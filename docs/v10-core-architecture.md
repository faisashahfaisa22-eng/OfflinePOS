# POS & Accounts Pro v10 Core Architecture

## Goal
Transform OfflinePOS into a complete business management system.

## Development Order

1. Core Database
2. Stock Movement Engine
3. Unified Transaction Engine
4. Customer/Supplier Ledger
5. Reports Engine
6. Cloud Sync
7. Multi User

## Core Rules

- Sale reduces stock.
- Purchase Receive increases stock.
- Returns adjust stock and balances.
- Every financial action creates a transaction record.

## Main Modules

- Dashboard
- Sales
- Inventory
- Customers
- Suppliers
- Expenses
- Cash Management
- Reports
- Cloud

## Current Migration Plan

Phase 1: Add database architecture and prepare modules without breaking existing features.
