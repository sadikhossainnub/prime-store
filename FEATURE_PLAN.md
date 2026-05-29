# Amer Dokan — Full Feature Implementation Plan

## 📌 Current State
- ✅ Customer management (add/edit/delete + photo + contact picker)
- ✅ Baki (credit) entry
- ✅ Payment collection
- ✅ Dashboard with stats
- ✅ Monthly & customer reports with bar chart
- ✅ SMS & WhatsApp reminders
- ✅ Google Drive backup/restore
- ✅ Local notifications (month-end reminder)
- ✅ Settings (shop info, backup, logout)
- ✅ Google Sign-In auth

---

## 🗺️ New Features — Phased Roadmap

---

## PHASE 1 — Inventory Management (ইনভেন্টরি)

### 1.1 New Data Models

#### `Product` model (`lib/models/product.dart`)
| Field | Type | Description |
|-------|------|-------------|
| id | int? | PK |
| name | TEXT | পণ্যের নাম |
| category | TEXT? | ক্যাটাগরি (চাল, ডাল, তেল...) |
| unit | TEXT | একক (kg, liter, pcs, dozen) |
| buyPrice | REAL | ক্রয় মূল্য |
| sellPrice | REAL | বিক্রয় মূল্য |
| currentStock | REAL | বর্তমান স্টক |
| minStockAlert | REAL | সর্বনিম্ন স্টক সতর্কতা |
| barcode | TEXT? | বারকোড (optional) |
| createdAt | TEXT | তৈরির তারিখ |

#### `StockMovement` model (`lib/models/stock_movement.dart`)
| Field | Type | Description |
|-------|------|-------------|
| id | int? | PK |
| productId | int | FK → products |
| type | TEXT | 'in' (purchase) / 'out' (sale) / 'adjustment' |
| quantity | REAL | পরিমাণ |
| referenceId | int? | FK → purchases.id or sales.id |
| date | TEXT | তারিখ |

### 1.2 New DB Tables
```sql
-- products table
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  category TEXT,
  unit TEXT NOT NULL DEFAULT 'pcs',
  buy_price REAL NOT NULL DEFAULT 0,
  sell_price REAL NOT NULL DEFAULT 0,
  current_stock REAL NOT NULL DEFAULT 0,
  min_stock_alert REAL NOT NULL DEFAULT 5,
  barcode TEXT,
  created_at TEXT NOT NULL
);

-- stock_movements table (audit trail)
CREATE TABLE stock_movements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  type TEXT NOT NULL,  -- 'in', 'out', 'adjustment'
  quantity REAL NOT NULL,
  reference_id INTEGER,
  date TEXT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
);
```

### 1.3 New Screens
- `lib/screens/inventory/inventory_screen.dart` — product list with stock levels
- `lib/screens/inventory/add_product_screen.dart` — add/edit product form
- `lib/screens/inventory/stock_adjustment_screen.dart` — manual stock correction
- `lib/screens/inventory/low_stock_screen.dart` — items below min_stock_alert

### 1.4 New Provider
- `lib/providers/inventory_provider.dart` — CRUD + stock queries

### 1.5 DB Version Migration
- Bump DB version: `1` → `2`
- Add `onUpgrade` handler in `DatabaseHelper`

---

## PHASE 2 — Purchase Management (ক্রয়)

### 2.1 New Data Models

#### `Supplier` model (`lib/models/supplier.dart`)
| Field | Type | Description |
|-------|------|-------------|
| id | int? | PK |
| name | TEXT | সরবরাহকারীর নাম |
| phone | TEXT | ফোন |
| address | TEXT? | ঠিকানা |
| totalDue | REAL | মোট বকেয়া (computed) |
| createdAt | TEXT | তৈরির তারিখ |

#### `Purchase` model (`lib/models/purchase.dart`)
| Field | Type | Description |
|-------|------|-------------|
| id | int? | PK |
| supplierId | int? | FK → suppliers (nullable = cash purchase) |
| invoiceNo | TEXT? | চালান নম্বর |
| totalAmount | REAL | মোট পরিমাণ |
| paidAmount | REAL | পরিশোধিত |
| dueAmount | REAL | বকেয়া (computed) |
| date | TEXT | তারিখ |
| note | TEXT? | নোট |
| createdAt | TEXT | তৈরির তারিখ |

#### `PurchaseItem` model (`lib/models/purchase_item.dart`)
| Field | Type | Description |
|-------|------|-------------|
| id | int? | PK |
| purchaseId | int | FK → purchases |
| productId | int | FK → products |
| quantity | REAL | পরিমাণ |
| buyPrice | REAL | ক্রয় মূল্য |
| totalPrice | REAL | মোট (quantity × buyPrice) |

### 2.2 New DB Tables
```sql
CREATE TABLE suppliers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE purchases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  supplier_id INTEGER,
  invoice_no TEXT,
  total_amount REAL NOT NULL,
  paid_amount REAL NOT NULL DEFAULT 0,
  date TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL
);

CREATE TABLE purchase_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity REAL NOT NULL,
  buy_price REAL NOT NULL,
  total_price REAL NOT NULL,
  FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products (id)
);
```

### 2.3 New Screens
- `lib/screens/purchase/purchase_list_screen.dart` — all purchases
- `lib/screens/purchase/add_purchase_screen.dart` — new purchase with item cart
- `lib/screens/purchase/purchase_detail_screen.dart` — purchase details + items
- `lib/screens/suppliers/supplier_list_screen.dart` — supplier management
- `lib/screens/suppliers/supplier_detail_screen.dart` — supplier ledger (dues)

### 2.4 Business Logic
- On purchase save → auto-increment `products.current_stock` for each item
- On purchase save → insert `stock_movements` records (type: 'in')
- Supplier due = `SUM(purchases.total_amount) - SUM(purchases.paid_amount)`

### 2.5 New Provider
- `lib/providers/purchase_provider.dart`
- `lib/providers/supplier_provider.dart`

---

## PHASE 3 — Sales Management (বিক্রয়)

### 3.1 New Data Models

#### `Sale` model (`lib/models/sale.dart`)
| Field | Type | Description |
|-------|------|-------------|
| id | int? | PK |
| customerId | int? | FK → customers (null = walk-in cash sale) |
| saleType | TEXT | 'cash' / 'baki' / 'partial' |
| totalAmount | REAL | মোট বিক্রয় |
| paidAmount | REAL | নগদ প্রাপ্ত |
| bakiAmount | REAL | বাকি (totalAmount - paidAmount) |
| invoiceNo | TEXT? | চালান নম্বর |
| date | TEXT | তারিখ |
| note | TEXT? | নোট |
| createdAt | TEXT | তৈরির তারিখ |

#### `SaleItem` model (`lib/models/sale_item.dart`)
| Field | Type | Description |
|-------|------|-------------|
| id | int? | PK |
| saleId | int | FK → sales |
| productId | int | FK → products |
| quantity | REAL | পরিমাণ |
| sellPrice | REAL | বিক্রয় মূল্য |
| discount | REAL | ছাড় |
| totalPrice | REAL | মোট |

### 3.2 New DB Tables
```sql
CREATE TABLE sales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER,
  sale_type TEXT NOT NULL DEFAULT 'cash',  -- 'cash', 'baki', 'partial'
  total_amount REAL NOT NULL,
  paid_amount REAL NOT NULL DEFAULT 0,
  baki_amount REAL NOT NULL DEFAULT 0,
  invoice_no TEXT,
  date TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
);

CREATE TABLE sale_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sale_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity REAL NOT NULL,
  sell_price REAL NOT NULL,
  discount REAL NOT NULL DEFAULT 0,
  total_price REAL NOT NULL,
  FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products (id)
);
```

### 3.3 New Screens
- `lib/screens/sales/sales_list_screen.dart` — all sales history
- `lib/screens/sales/add_sale_screen.dart` — POS-style sale entry with product cart
- `lib/screens/sales/sale_detail_screen.dart` — sale receipt view

### 3.4 Business Logic
- On sale save → auto-decrement `products.current_stock` for each item
- On sale save → insert `stock_movements` records (type: 'out')
- If `saleType == 'baki'` or `'partial'` → auto-create a `BakiTransaction` for the customer
- Low stock notification if stock falls below `min_stock_alert`

### 3.5 New Provider
- `lib/providers/sales_provider.dart`

---

## PHASE 4 — Enhanced Features

### 4.1 Bulk SMS/WhatsApp Reminder
- File: `lib/screens/reminders/bulk_reminder_screen.dart`
- List all customers with `totalBaki > 0`
- Checkbox select + "Send All" button
- Uses existing `SmsService` & `WhatsappService`

### 4.2 PDF Export
- Add `pdf` package to `pubspec.yaml`
- File: `lib/services/pdf_service.dart`
- Generate customer statement PDF
- Generate sales invoice PDF
- Share via existing `share_plus`

### 4.3 Credit Limit per Customer
- Add `creditLimit REAL DEFAULT 0` column to `customers` table (migration)
- Show warning badge when `totalBaki >= creditLimit`
- Block new baki entry if limit exceeded (with override option)

### 4.4 PIN Lock
- Add `local_auth` package
- File: `lib/screens/auth/pin_lock_screen.dart`
- Toggle in Settings

### 4.5 CSV Export
- File: `lib/services/export_service.dart`
- Export transactions, sales, purchases to `.csv`
- Share via `share_plus`

### 4.6 Yearly Report
- Add 3rd tab to `ReportsScreen`
- 12-month bar chart (baki vs collection vs sales)

### 4.7 Top Defaulters Widget
- Add to Dashboard below recent transactions
- Top 5 customers by outstanding baki
- Quick "Send Reminder" action

---

## PHASE 5 — Navigation & UI Updates

### 5.1 Updated Bottom Navigation (5 tabs)
```
Dashboard | Customers | Sales/POS | Inventory | Reports
```
> Settings moved to Dashboard header icon (top-right)

### 5.2 Updated Dashboard Stats (6 cards)
| Card | Data Source |
|------|-------------|
| মোট বাকি | existing |
| আজকের বিক্রয় | sales table |
| আজকের ক্রয় | purchases table |
| আজকের আদায় | existing |
| কম স্টক | products below min_stock_alert |
| মোট লাভ | sales.total - purchases.total |

### 5.3 Quick Action FAB (updated)
Add 4 options:
1. বাকি যোগ করুন (existing)
2. টাকা আদায় করুন (existing)
3. নতুন বিক্রয় (new)
4. নতুন ক্রয় (new)

---

## 🗄️ Final Database Schema (v4)

```
DB version: 1 → 4 (incremental migrations)

Tables:
  v1: customers, transactions, payments
  v2: + products, stock_movements
  v3: + suppliers, purchases, purchase_items
  v4: + sales, sale_items
       + ALTER customers ADD COLUMN credit_limit REAL DEFAULT 0
```

---

## 📂 Final Project Structure (new files only)

```
lib/
├── models/
│   ├── product.dart              [NEW]
│   ├── stock_movement.dart       [NEW]
│   ├── supplier.dart             [NEW]
│   ├── purchase.dart             [NEW]
│   ├── purchase_item.dart        [NEW]
│   ├── sale.dart                 [NEW]
│   └── sale_item.dart            [NEW]
├── providers/
│   ├── inventory_provider.dart   [NEW]
│   ├── supplier_provider.dart    [NEW]
│   ├── purchase_provider.dart    [NEW]
│   └── sales_provider.dart       [NEW]
├── screens/
│   ├── inventory/
│   │   ├── inventory_screen.dart         [NEW]
│   │   ├── add_product_screen.dart       [NEW]
│   │   └── stock_adjustment_screen.dart  [NEW]
│   ├── purchase/
│   │   ├── purchase_list_screen.dart     [NEW]
│   │   ├── add_purchase_screen.dart      [NEW]
│   │   └── purchase_detail_screen.dart   [NEW]
│   ├── suppliers/
│   │   ├── supplier_list_screen.dart     [NEW]
│   │   └── supplier_detail_screen.dart   [NEW]
│   ├── sales/
│   │   ├── sales_list_screen.dart        [NEW]
│   │   ├── add_sale_screen.dart          [NEW]
│   │   └── sale_detail_screen.dart       [NEW]
│   └── reminders/
│       └── bulk_reminder_screen.dart     [NEW]
└── services/
    ├── pdf_service.dart          [NEW]
    └── export_service.dart       [NEW]
```

---

## 📦 New Dependencies to Add

```yaml
# pubspec.yaml additions
pdf: ^3.11.0          # PDF generation
printing: ^5.13.0     # PDF preview & share
local_auth: ^2.3.0    # PIN/biometric lock
```

> `share_plus`, `sqflite`, `fl_chart`, `intl` — already installed ✅

---

## 🔢 Implementation Order (Step by Step)

| Step | Task | Phase |
|------|------|-------|
| 1 | DB migration system (v1→v4) + all new tables | 1 |
| 2 | Product model + InventoryProvider + CRUD | 1 |
| 3 | Inventory screens (list, add, stock adjust) | 1 |
| 4 | Supplier model + SupplierProvider | 2 |
| 5 | Purchase model + PurchaseProvider + stock-in logic | 2 |
| 6 | Purchase screens (list, add with cart, detail) | 2 |
| 7 | Sale model + SalesProvider + stock-out + baki-link logic | 3 |
| 8 | Sales screens (list, POS add screen, detail/receipt) | 3 |
| 9 | Update Dashboard (6 cards + top defaulters) | 5 |
| 10 | Update Bottom Nav (5 tabs) + FAB (4 actions) | 5 |
| 11 | Update Reports (yearly tab + profit/loss) | 4 |
| 12 | Bulk reminder screen | 4 |
| 13 | PDF service (invoice + statement) | 4 |
| 14 | CSV export service | 4 |
| 15 | Credit limit feature | 4 |
| 16 | PIN lock | 4 |

---

## ⚠️ Key Business Rules

1. **Sale → Baki link**: When a sale has `bakiAmount > 0`, automatically create a `BakiTransaction` for that customer so the existing baki ledger stays accurate.
2. **Purchase → Stock**: Saving a purchase auto-increments product stock and logs a `stock_movement` (type: 'in').
3. **Sale → Stock**: Saving a sale auto-decrements product stock and logs a `stock_movement` (type: 'out').
4. **DB Migration**: Use SQLite `onUpgrade` with version checks — never drop existing tables.
5. **Offline First**: All features work 100% offline. No new network dependencies.
6. **Backward Compatibility**: Existing baki/payment flow remains unchanged — sales module is additive.
