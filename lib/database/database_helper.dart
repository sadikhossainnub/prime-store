import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../models/sale.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB('amer_dokan.db');
    return _database!;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      try {
        if (_database!.isOpen) {
          await _database!.close();
        }
      } catch (_) {}
      _database = null;
    }
  }

  Future<Database> reloadDatabase() async {
    await closeDatabase();
    _database = await _initDB('amer_dokan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 6, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        photo_path TEXT,
        credit_limit REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
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
        photo_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
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
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        buy_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        sale_type TEXT NOT NULL DEFAULT 'cash',
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        baki_amount REAL NOT NULL DEFAULT 0,
        invoice_no TEXT,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
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
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
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
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER,
          invoice_no TEXT,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0,
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity REAL NOT NULL,
          buy_price REAL NOT NULL,
          total_price REAL NOT NULL,
          FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER,
          sale_type TEXT NOT NULL DEFAULT 'cash',
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0,
          baki_amount REAL NOT NULL DEFAULT 0,
          invoice_no TEXT,
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity REAL NOT NULL,
          sell_price REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0,
          total_price REAL NOT NULL,
          FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
      // Add credit_limit column to existing customers table
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN credit_limit REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // Add photo_path column to products
      try {
        await db.execute('ALTER TABLE products ADD COLUMN photo_path TEXT');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recycle_bin (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_type TEXT NOT NULL,
          item_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          subtitle TEXT,
          data_json TEXT NOT NULL,
          deleted_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ─── Customer Operations ─────────────────────────────────────────────

  Future<int> createCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT c.*,
      (COALESCE((SELECT SUM(amount) FROM transactions WHERE customer_id = c.id), 0) -
       COALESCE((SELECT SUM(amount) FROM payments WHERE customer_id = c.id), 0)) as total_baki
      FROM customers c
      ORDER BY name ASC
    ''');
    return result.map((json) => Customer.fromMap(json)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT c.*,
      (COALESCE((SELECT SUM(amount) FROM transactions WHERE customer_id = c.id), 0) -
       COALESCE((SELECT SUM(amount) FROM payments WHERE customer_id = c.id), 0)) as total_baki
      FROM customers c WHERE c.id = ?
    ''', [id]);
    return result.isNotEmpty ? Customer.fromMap(result.first) : null;
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final custs = await txn.query('customers', where: 'id = ?', whereArgs: [id]);
      if (custs.isNotEmpty) {
        final cust = custs.first;
        final txns = await txn.query('transactions', where: 'customer_id = ?', whereArgs: [id]);
        final pymts = await txn.query('payments', where: 'customer_id = ?', whereArgs: [id]);
        final data = {
          'customer': cust,
          'transactions': txns,
          'payments': pymts,
        };
        await txn.insert('recycle_bin', {
          'item_type': 'customer',
          'item_id': id,
          'title': cust['name'] ?? 'কাস্টমার #$id',
          'subtitle': 'ফোন: ${cust['phone'] ?? 'N/A'}',
          'data_json': jsonEncode(data),
          'deleted_at': DateTime.now().toIso8601String(),
        });
      }
      await txn.delete('transactions', where: 'customer_id = ?', whereArgs: [id]);
      await txn.delete('payments', where: 'customer_id = ?', whereArgs: [id]);
      return await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Transaction Operations ──────────────────────────────────────────

  Future<int> createTransaction(BakiTransaction transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<BakiTransaction>> getTransactionsByCustomer(int customerId) async {
    final db = await instance.database;
    final result = await db.query('transactions',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'date DESC');
    return result.map((json) => BakiTransaction.fromMap(json)).toList();
  }

  // ─── Payment Operations ──────────────────────────────────────────────

  Future<int> createPayment(Payment payment) async {
    final db = await instance.database;
    return await db.insert('payments', payment.toMap());
  }

  Future<List<Payment>> getPaymentsByCustomer(int customerId) async {
    final db = await instance.database;
    final result = await db.query('payments',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'date DESC');
    return result.map((json) => Payment.fromMap(json)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final txns = await txn.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (txns.isNotEmpty) {
        final t = txns.first;
        await txn.insert('recycle_bin', {
          'item_type': 'transaction',
          'item_id': id,
          'title': 'বাকি লেনদেন #$id (৳${t['amount']})',
          'subtitle': 'বিবরণ: ${t['description'] ?? 'N/A'}',
          'data_json': jsonEncode(t),
          'deleted_at': DateTime.now().toIso8601String(),
        });
      }
      return await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deletePayment(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final pmts = await txn.query('payments', where: 'id = ?', whereArgs: [id]);
      if (pmts.isNotEmpty) {
        final p = pmts.first;
        await txn.insert('recycle_bin', {
          'item_type': 'payment',
          'item_id': id,
          'title': 'জমা পেমেন্ট #$id (৳${p['amount']})',
          'subtitle': 'নোট: ${p['note'] ?? 'N/A'}',
          'data_json': jsonEncode(p),
          'deleted_at': DateTime.now().toIso8601String(),
        });
      }
      return await txn.delete('payments', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Product Operations ──────────────────────────────────────────────

  Future<int> createProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products', orderBy: 'name ASC');
    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT * FROM products WHERE current_stock <= min_stock_alert ORDER BY current_stock ASC');
    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final prods = await txn.query('products', where: 'id = ?', whereArgs: [id]);
      if (prods.isNotEmpty) {
        final prod = prods.first;
        await txn.insert('recycle_bin', {
          'item_type': 'product',
          'item_id': id,
          'title': prod['name'] ?? 'পণ্য #$id',
          'subtitle': 'বিক্রয় মূল্য: ৳${prod['sell_price']}, স্টক: ${prod['current_stock']}',
          'data_json': jsonEncode(prod),
          'deleted_at': DateTime.now().toIso8601String(),
        });
      }
      return await txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> adjustStock(int productId, double delta) async {
    final db = await instance.database;
    await db.rawUpdate(
        'UPDATE products SET current_stock = current_stock + ? WHERE id = ?', [delta, productId]);
  }

  // ─── Supplier Operations ─────────────────────────────────────────────

  Future<int> createSupplier(Supplier supplier) async {
    final db = await instance.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT s.*,
      (COALESCE((SELECT SUM(total_amount) FROM purchases WHERE supplier_id = s.id), 0) -
       COALESCE((SELECT SUM(paid_amount) FROM purchases WHERE supplier_id = s.id), 0)) as total_due
      FROM suppliers s ORDER BY name ASC
    ''');
    return result.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await instance.database;
    return await db.update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<int> deleteSupplier(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final sups = await txn.query('suppliers', where: 'id = ?', whereArgs: [id]);
      if (sups.isNotEmpty) {
        final sup = sups.first;
        await txn.insert('recycle_bin', {
          'item_type': 'supplier',
          'item_id': id,
          'title': sup['name'] ?? 'ডিলার #$id',
          'subtitle': 'ফোন: ${sup['phone'] ?? 'N/A'}',
          'data_json': jsonEncode(sup),
          'deleted_at': DateTime.now().toIso8601String(),
        });
      }
      return await txn.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Purchase Operations ─────────────────────────────────────────────

  Future<int> createPurchase(Purchase purchase, List<PurchaseItem> items) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', purchase.toMap());
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['purchase_id'] = purchaseId;
        await txn.insert('purchase_items', itemMap);
        // Increment stock
        await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [item.quantity, item.productId]);
      }
      return purchaseId;
    });
  }

  Future<List<Purchase>> getAllPurchases() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as supplier_name
      FROM purchases p
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      ORDER BY p.date DESC
    ''');
    return result.map((e) => Purchase.fromMap(e)).toList();
  }

  Future<List<Purchase>> getPurchasesBySupplier(int supplierId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as supplier_name
      FROM purchases p
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE p.supplier_id = ?
      ORDER BY p.date DESC
    ''', [supplierId]);
    return result.map((e) => Purchase.fromMap(e)).toList();
  }

  Future<List<PurchaseItem>> getPurchaseItems(int purchaseId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT pi.*, p.name as product_name, p.unit as product_unit
      FROM purchase_items pi
      JOIN products p ON pi.product_id = p.id
      WHERE pi.purchase_id = ?
    ''', [purchaseId]);
    return result.map((e) => PurchaseItem.fromMap(e)).toList();
  }

  Future<int> deletePurchase(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final purchases = await txn.query('purchases', where: 'id = ?', whereArgs: [id]);
      if (purchases.isNotEmpty) {
        final purchase = purchases.first;
        final items = await txn.rawQuery(
            'SELECT * FROM purchase_items WHERE purchase_id = ?', [id]);
        final data = {
          'purchase': purchase,
          'items': items,
        };
        await txn.insert('recycle_bin', {
          'item_type': 'purchase',
          'item_id': id,
          'title': 'ক্রয় (Invoice: ${purchase['invoice_no'] ?? id})',
          'subtitle': 'মোট: ৳${purchase['total_amount']}, ডিলার: ${purchase['supplier_name'] ?? 'N/A'}',
          'data_json': jsonEncode(data),
          'deleted_at': DateTime.now().toIso8601String(),
        });

        // Reverse stock
        for (final item in items) {
          await txn.rawUpdate(
              'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
              [item['quantity'], item['product_id']]);
        }
        await txn.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [id]);
      }
      return await txn.delete('purchases', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Sale Operations ─────────────────────────────────────────────────

  Future<int> createSale(Sale sale, List<SaleItem> items) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final saleId = await txn.insert('sales', sale.toMap());
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['sale_id'] = saleId;
        await txn.insert('sale_items', itemMap);
        // Decrement stock
        await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [item.quantity, item.productId]);
      }
      // If baki sale, auto-create a baki transaction
      if (sale.bakiAmount > 0 && sale.customerId != null) {
        await txn.insert('transactions', {
          'customer_id': sale.customerId,
          'amount': sale.bakiAmount,
          'description': 'বিক্রয় থেকে বাকি (Invoice: ${sale.invoiceNo ?? saleId})',
          'date': sale.date.toIso8601String(),
          'created_at': sale.createdAt.toIso8601String(),
        });
      }
      return saleId;
    });
  }

  Future<List<Sale>> getAllSales() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT s.*, c.name as customer_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      ORDER BY s.date DESC
    ''');
    return result.map((e) => Sale.fromMap(e)).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT si.*, p.name as product_name, p.unit as product_unit
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [saleId]);
    return result.map((e) => SaleItem.fromMap(e)).toList();
  }

  Future<int> deleteSale(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final sales = await txn.query('sales', where: 'id = ?', whereArgs: [id]);
      if (sales.isNotEmpty) {
        final sale = sales.first;
        final invoiceNo = sale['invoice_no'];
        final items = await txn.rawQuery(
            'SELECT * FROM sale_items WHERE sale_id = ?', [id]);

        List<Map<String, dynamic>> associatedTxns = [];
        if (invoiceNo != null && invoiceNo.toString().isNotEmpty) {
          associatedTxns = await txn.query('transactions',
              where: 'description LIKE ?',
              whereArgs: ['%Invoice: $invoiceNo%']);
          await txn.delete('transactions',
              where: 'description LIKE ?',
              whereArgs: ['%Invoice: $invoiceNo%']);
        }

        final data = {
          'sale': sale,
          'items': items,
          'transaction': associatedTxns.isNotEmpty ? associatedTxns.first : null,
        };

        await txn.insert('recycle_bin', {
          'item_type': 'sale',
          'item_id': id,
          'title': 'বিক্রয় (Invoice: ${invoiceNo ?? id})',
          'subtitle': 'মোট: ৳${sale['total_amount']}, কাস্টমার: ${sale['customer_name'] ?? 'নগদ'}',
          'data_json': jsonEncode(data),
          'deleted_at': DateTime.now().toIso8601String(),
        });

        // Reverse stock
        for (final item in items) {
          await txn.rawUpdate(
              'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
              [item['quantity'], item['product_id']]);
        }
        await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [id]);
      }
      return await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> cleanupOrphanedSaleTransactions() async {
    final db = await instance.database;
    final txns = await db.query('transactions', where: "description LIKE '%Invoice:%'");
    final sales = await db.query('sales', columns: ['id', 'invoice_no']);
    final activeInvoices = sales.map((s) => s['invoice_no']?.toString()).whereType<String>().toSet();
    final activeSaleIds = sales.map((s) => s['id']?.toString()).whereType<String>().toSet();

    for (final txn in txns) {
      final desc = txn['description']?.toString() ?? '';
      final txnId = txn['id'];
      final match = RegExp(r'Invoice:\s*([^\s\)]+)').firstMatch(desc);
      if (match != null) {
        final inv = match.group(1);
        if (inv != null && !activeInvoices.contains(inv) && !activeSaleIds.contains(inv)) {
          await db.delete('transactions', where: 'id = ?', whereArgs: [txnId]);
        }
      }
    }
  }

  // ─── Dashboard Stats ─────────────────────────────────────────────────

  Future<Map<String, double>> getDashboardStats() async {
    final db = await instance.database;
    await cleanupOrphanedSaleTransactions();
    final today = DateTime.now().toIso8601String().split('T')[0];

    final totalBakiResult =
        await db.rawQuery('SELECT SUM(amount) as total FROM transactions');
    final totalPaidResult =
        await db.rawQuery('SELECT SUM(amount) as total FROM payments');
    final todayBakiResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE date LIKE ?', ['$today%']);
    final todayPaidResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE date LIKE ?', ['$today%']);
    final todaySalesResult = await db.rawQuery(
        'SELECT SUM(total_amount) as total FROM sales WHERE date LIKE ?', ['$today%']);
    final todayPurchasesResult = await db.rawQuery(
        'SELECT SUM(total_amount) as total FROM purchases WHERE date LIKE ?', ['$today%']);
    final totalSalesResult =
        await db.rawQuery('SELECT SUM(total_amount) as total FROM sales');
    final totalPurchasesResult =
        await db.rawQuery('SELECT SUM(total_amount) as total FROM purchases');
    final lowStockResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE current_stock <= min_stock_alert');
    final activeCustomersResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT customer_id) as count FROM transactions');

    double totalBaki = (totalBakiResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalPaid = (totalPaidResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalSales = (totalSalesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalPurchases = (totalPurchasesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'total_due': totalBaki - totalPaid,
      'today_baki': (todayBakiResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'today_paid': (todayPaidResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'today_sales': (todaySalesResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'today_purchases': (todayPurchasesResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'total_sales': totalSales,
      'total_profit': totalSales - totalPurchases,
      'low_stock_count': (lowStockResult.first['count'] as num?)?.toDouble() ?? 0.0,
      'active_customers': (activeCustomersResult.first['count'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 10}) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 'baki' as type, t.amount, t.date, c.name as customer_name, t.description as note
      FROM transactions t JOIN customers c ON t.customer_id = c.id
      UNION ALL
      SELECT 'payment' as type, p.amount, p.date, c.name as customer_name, p.note as note
      FROM payments p JOIN customers c ON p.customer_id = c.id
      UNION ALL
      SELECT 'sale' as type, s.total_amount as amount, s.date,
        COALESCE(c.name, 'নগদ বিক্রয়') as customer_name, s.note
      FROM sales s LEFT JOIN customers c ON s.customer_id = c.id
      ORDER BY date DESC LIMIT ?
    ''', [limit]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getTopDefaulters({int limit = 5}) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.id, c.name, c.phone,
        (COALESCE((SELECT SUM(amount) FROM transactions WHERE customer_id = c.id), 0) -
         COALESCE((SELECT SUM(amount) FROM payments WHERE customer_id = c.id), 0)) as total_baki
      FROM customers c
      GROUP BY c.id
      HAVING total_baki > 0
      ORDER BY total_baki DESC
      LIMIT ?
    ''', [limit]);
  }

  // ─── Reports ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMonthlyReport(int year, int month) async {
    final db = await instance.database;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final end = month < 12
        ? '$year-${(month + 1).toString().padLeft(2, '0')}-01'
        : '${year + 1}-01-01';
    return await db.rawQuery('''
      SELECT date(t.date) as day,
        SUM(t.amount) as baki,
        COALESCE((SELECT SUM(p.amount) FROM payments p WHERE date(p.date) = date(t.date)), 0) as paid
      FROM transactions t
      WHERE t.date >= ? AND t.date < ?
      GROUP BY date(t.date) ORDER BY day ASC
    ''', [start, end]);
  }

  Future<List<Map<String, dynamic>>> getMonthlySalesReport(int year, int month) async {
    final db = await instance.database;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final end = month < 12
        ? '$year-${(month + 1).toString().padLeft(2, '0')}-01'
        : '${year + 1}-01-01';
    return await db.rawQuery('''
      SELECT date(s.date) as day,
        SUM(s.total_amount) as sales,
        COALESCE((SELECT SUM(total_amount) FROM purchases p WHERE date(p.date) = date(s.date)), 0) as purchases
      FROM sales s
      WHERE s.date >= ? AND s.date < ?
      GROUP BY date(s.date) ORDER BY day ASC
    ''', [start, end]);
  }

  Future<List<Map<String, dynamic>>> getCustomerReport() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.name, c.phone,
        COALESCE((SELECT SUM(amount) FROM transactions WHERE customer_id = c.id), 0) as total_baki,
        COALESCE((SELECT SUM(amount) FROM payments WHERE customer_id = c.id), 0) as total_paid
      FROM customers c ORDER BY total_baki DESC
    ''');
  }

  // ─── Recycle Bin Operations ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecycleBinItems() async {
    final db = await instance.database;
    return await db.query('recycle_bin', orderBy: 'deleted_at DESC');
  }

  Future<int> deleteFromRecycleBin(int binId) async {
    final db = await instance.database;
    return await db.delete('recycle_bin', where: 'id = ?', whereArgs: [binId]);
  }

  Future<int> emptyRecycleBin() async {
    final db = await instance.database;
    return await db.delete('recycle_bin');
  }

  Future<bool> restoreFromRecycleBin(int binId) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final records = await txn.query('recycle_bin', where: 'id = ?', whereArgs: [binId]);
      if (records.isEmpty) return false;
      final rec = records.first;
      final type = rec['item_type'] as String;
      final data = jsonDecode(rec['data_json'] as String) as Map<String, dynamic>;

      if (type == 'product') {
        await txn.insert('products', data, conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (type == 'customer') {
        final custData = Map<String, dynamic>.from(data['customer']);
        await txn.insert('customers', custData, conflictAlgorithm: ConflictAlgorithm.replace);
        if (data['transactions'] != null) {
          for (final t in (data['transactions'] as List)) {
            await txn.insert('transactions', Map<String, dynamic>.from(t), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (data['payments'] != null) {
          for (final p in (data['payments'] as List)) {
            await txn.insert('payments', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      } else if (type == 'supplier') {
        await txn.insert('suppliers', data, conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (type == 'sale') {
        final saleData = Map<String, dynamic>.from(data['sale']);
        final saleId = await txn.insert('sales', saleData, conflictAlgorithm: ConflictAlgorithm.replace);
        if (data['items'] != null) {
          for (final i in (data['items'] as List)) {
            final itemMap = Map<String, dynamic>.from(i);
            itemMap['sale_id'] = saleId;
            await txn.insert('sale_items', itemMap, conflictAlgorithm: ConflictAlgorithm.replace);
            // Decrement stock back
            await txn.rawUpdate(
                'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
                [itemMap['quantity'], itemMap['product_id']]);
          }
        }
        if (data['transaction'] != null) {
          await txn.insert('transactions', Map<String, dynamic>.from(data['transaction']), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } else if (type == 'purchase') {
        final purchaseData = Map<String, dynamic>.from(data['purchase']);
        final purchaseId = await txn.insert('purchases', purchaseData, conflictAlgorithm: ConflictAlgorithm.replace);
        if (data['items'] != null) {
          for (final i in (data['items'] as List)) {
            final itemMap = Map<String, dynamic>.from(i);
            itemMap['purchase_id'] = purchaseId;
            await txn.insert('purchase_items', itemMap, conflictAlgorithm: ConflictAlgorithm.replace);
            // Increment stock back
            await txn.rawUpdate(
                'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
                [itemMap['quantity'], itemMap['product_id']]);
          }
        }
      } else if (type == 'transaction') {
        await txn.insert('transactions', data, conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (type == 'payment') {
        await txn.insert('payments', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await txn.delete('recycle_bin', where: 'id = ?', whereArgs: [binId]);
      return true;
    });
  }

  // ─── Bulk Delete Operations (Admin) ──────────────────────────────────

  /// Delete all products and related purchase_items/sale_items
  Future<void> deleteAllProducts() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('purchase_items');
      await txn.delete('products');
    });
  }

  /// Delete all customers and their transactions/payments
  Future<void> deleteAllCustomers() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('payments');
      await txn.delete('customers');
    });
  }

  /// Delete all sales and sale_items
  Future<void> deleteAllSales() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
    });
  }

  /// Delete all purchases and purchase_items
  Future<void> deleteAllPurchases() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('purchase_items');
      await txn.delete('purchases');
    });
  }

  /// Delete all suppliers
  Future<void> deleteAllSuppliers() async {
    final db = await instance.database;
    await db.delete('suppliers');
  }

  /// Delete all baki/transaction records and payments
  Future<void> deleteAllTransactions() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('payments');
    });
  }

  /// Delete ALL data from all tables (nuclear option)
  Future<void> deleteAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('purchase_items');
      await txn.delete('transactions');
      await txn.delete('payments');
      await txn.delete('sales');
      await txn.delete('purchases');
      await txn.delete('products');
      await txn.delete('customers');
      await txn.delete('suppliers');
      await txn.delete('recycle_bin');
    });
  }

  /// Get counts for all tables (for display)
  Future<Map<String, int>> getAllDataCounts() async {
    final db = await instance.database;
    final products = (await db.rawQuery('SELECT COUNT(*) as c FROM products')).first['c'] as int;
    final customers = (await db.rawQuery('SELECT COUNT(*) as c FROM customers')).first['c'] as int;
    final sales = (await db.rawQuery('SELECT COUNT(*) as c FROM sales')).first['c'] as int;
    final purchases = (await db.rawQuery('SELECT COUNT(*) as c FROM purchases')).first['c'] as int;
    final suppliers = (await db.rawQuery('SELECT COUNT(*) as c FROM suppliers')).first['c'] as int;
    final transactions = (await db.rawQuery('SELECT COUNT(*) as c FROM transactions')).first['c'] as int;
    final payments = (await db.rawQuery('SELECT COUNT(*) as c FROM payments')).first['c'] as int;
    return {
      'products': products,
      'customers': customers,
      'sales': sales,
      'purchases': purchases,
      'suppliers': suppliers,
      'transactions': transactions,
      'payments': payments,
    };
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
