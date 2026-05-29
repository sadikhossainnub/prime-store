import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../database/database_helper.dart';

class PurchaseProvider with ChangeNotifier {
  List<Purchase> _purchases = [];
  bool _isLoading = false;

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading;

  Future<void> fetchPurchases() async {
    _isLoading = true;
    notifyListeners();
    _purchases = await DatabaseHelper.instance.getAllPurchases();
    _isLoading = false;
    notifyListeners();
  }

  Future<int> addPurchase(Purchase purchase, List<PurchaseItem> items) async {
    final id = await DatabaseHelper.instance.createPurchase(purchase, items);
    await fetchPurchases();
    return id;
  }

  Future<void> deletePurchase(int id) async {
    await DatabaseHelper.instance.deletePurchase(id);
    await fetchPurchases();
  }

  Future<List<PurchaseItem>> getPurchaseItems(int purchaseId) async {
    return await DatabaseHelper.instance.getPurchaseItems(purchaseId);
  }
}
