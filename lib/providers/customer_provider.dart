import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../database/database_helper.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  Future<void> fetchCustomers() async {
    _isLoading = true;
    notifyListeners();
    _customers = await DatabaseHelper.instance.getAllCustomers();
    _isLoading = false;
    notifyListeners();
  }

  Future<int> addCustomer(String name, String phone, {String? address, String? photoPath}) async {
    final customer = Customer(
      name: name,
      phone: phone,
      address: address,
      photoPath: photoPath,
      createdAt: DateTime.now(),
    );
    final id = await DatabaseHelper.instance.createCustomer(customer);
    await fetchCustomers();
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    await DatabaseHelper.instance.updateCustomer(customer);
    await fetchCustomers();
  }

  Future<void> deleteCustomer(int id) async {
    await DatabaseHelper.instance.deleteCustomer(id);
    await fetchCustomers();
  }

  Future<Customer?> getCustomer(int id) async {
    return await DatabaseHelper.instance.getCustomerById(id);
  }

  List<Customer> searchCustomers(String query) {
    if (query.isEmpty) return _customers;
    return _customers.where((c) =>
      c.name.toLowerCase().contains(query.toLowerCase()) ||
      c.phone.contains(query)
    ).toList();
  }
}
