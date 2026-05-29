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
    if (_database != null) return _database!;
    _database = await _initDB('amer_dokan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 4, onCreate: _createDB, onUpgrade: _upgradeDB);
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
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
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
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
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
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
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
      // Reverse stock
      final items = await txn.rawQuery(
          'SELECT product_id, quantity FROM purchase_items WHERE purchase_id = ?', [id]);
      for (final item in items) {
        await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [item['quantity'], item['product_id']]);
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
      // Reverse stock
      final items = await txn.rawQuery(
          'SELECT product_id, quantity FROM sale_items WHERE sale_id = ?', [id]);
      for (final item in items) {
        await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [item['quantity'], item['product_id']]);
      }
      return await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Dashboard Stats ─────────────────────────────────────────────────

  Future<Map<String, double>> getDashboardStats() async {
    final db = await instance.database;
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
