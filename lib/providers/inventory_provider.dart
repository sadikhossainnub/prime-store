import 'package:flutter/material.dart';
import '../models/product.dart';
import '../database/database_helper.dart';

class InventoryProvider with ChangeNotifier {
  List<Product> _products = [];
  List<Product> _lowStockProducts = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  List<Product> get lowStockProducts => _lowStockProducts;
  bool get isLoading => _isLoading;
  int get lowStockCount => _lowStockProducts.length;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();
    _products = await DatabaseHelper.instance.getAllProducts();
    _lowStockProducts = _products.where((p) => p.isLowStock).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    await DatabaseHelper.instance.createProduct(product);
    await fetchProducts();
  }

  Future<void> updateProduct(Product product) async {
    await DatabaseHelper.instance.updateProduct(product);
    await fetchProducts();
  }

  Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
    await fetchProducts();
  }

  Future<void> adjustStock(int productId, double delta) async {
    await DatabaseHelper.instance.adjustStock(productId, delta);
    await fetchProducts();
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;
    final q = query.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.category?.toLowerCase().contains(q) ?? false))
        .toList();
  }
}
