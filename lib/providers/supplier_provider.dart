import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../database/database_helper.dart';

class SupplierProvider with ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = false;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;

  Future<void> fetchSuppliers() async {
    _isLoading = true;
    notifyListeners();
    _suppliers = await DatabaseHelper.instance.getAllSuppliers();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSupplier(String name, String phone, {String? address}) async {
    final supplier = Supplier(
      name: name,
      phone: phone,
      address: address,
      createdAt: DateTime.now(),
    );
    await DatabaseHelper.instance.createSupplier(supplier);
    await fetchSuppliers();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await DatabaseHelper.instance.updateSupplier(supplier);
    await fetchSuppliers();
  }

  Future<void> deleteSupplier(int id) async {
    await DatabaseHelper.instance.deleteSupplier(id);
    await fetchSuppliers();
  }

  Future<List<Purchase>> getSupplierPurchases(int supplierId) async {
    return await DatabaseHelper.instance.getPurchasesBySupplier(supplierId);
  }

  List<Supplier> searchSuppliers(String query) {
    if (query.isEmpty) return _suppliers;
    final q = query.toLowerCase();
    return _suppliers
        .where((s) =>
            s.name.toLowerCase().contains(q) || s.phone.contains(query))
        .toList();
  }
}
