import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../database/database_helper.dart';

class TransactionProvider with ChangeNotifier {
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  Future<void> addBaki(int customerId, double amount, String? description) async {
    _isProcessing = true;
    notifyListeners();

    final transaction = BakiTransaction(
      customerId: customerId,
      amount: amount,
      description: description,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.createTransaction(transaction);
    _isProcessing = false;
    notifyListeners();
  }

  Future<void> addPayment(int customerId, double amount, String? note) async {
    _isProcessing = true;
    notifyListeners();

    final payment = Payment(
      customerId: customerId,
      amount: amount,
      note: note,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.createPayment(payment);
    _isProcessing = false;
    notifyListeners();
  }

  Future<List<BakiTransaction>> getTransactions(int customerId) async {
    return await DatabaseHelper.instance.getTransactionsByCustomer(customerId);
  }

  Future<List<Payment>> getPayments(int customerId) async {
    return await DatabaseHelper.instance.getPaymentsByCustomer(customerId);
  }
}
