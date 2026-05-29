import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../database/database_helper.dart';

class SalesProvider with ChangeNotifier {
  List<Sale> _sales = [];
  bool _isLoading = false;

  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;

  Future<void> fetchSales() async {
    _isLoading = true;
    notifyListeners();
    _sales = await DatabaseHelper.instance.getAllSales();
    _isLoading = false;
    notifyListeners();
  }

  Future<int> addSale(Sale sale, List<SaleItem> items) async {
    final id = await DatabaseHelper.instance.createSale(sale, items);
    await fetchSales();
    return id;
  }

  Future<void> deleteSale(int id) async {
    await DatabaseHelper.instance.deleteSale(id);
    await fetchSales();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    return await DatabaseHelper.instance.getSaleItems(saleId);
  }
}
