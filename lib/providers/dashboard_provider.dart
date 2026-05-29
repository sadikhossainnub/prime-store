import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class DashboardProvider with ChangeNotifier {
  double _totalDue = 0.0;
  double _todayBaki = 0.0;
  double _todayPaid = 0.0;
  double _todaySales = 0.0;
  double _todayPurchases = 0.0;
  double _totalSales = 0.0;
  double _totalProfit = 0.0;
  double _lowStockCount = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _topDefaulters = [];
  bool _isLoading = false;

  double get totalDue => _totalDue;
  double get todayBaki => _todayBaki;
  double get todayPaid => _todayPaid;
  double get todaySales => _todaySales;
  double get todayPurchases => _todayPurchases;
  double get totalSales => _totalSales;
  double get totalProfit => _totalProfit;
  int get lowStockCount => _lowStockCount.toInt();
  List<Map<String, dynamic>> get recentTransactions => _recentTransactions;
  List<Map<String, dynamic>> get topDefaulters => _topDefaulters;
  bool get isLoading => _isLoading;

  Future<void> fetchStats() async {
    _isLoading = true;
    notifyListeners();

    final stats = await DatabaseHelper.instance.getDashboardStats();
    _totalDue = stats['total_due'] ?? 0.0;
    _todayBaki = stats['today_baki'] ?? 0.0;
    _todayPaid = stats['today_paid'] ?? 0.0;
    _todaySales = stats['today_sales'] ?? 0.0;
    _todayPurchases = stats['today_purchases'] ?? 0.0;
    _totalSales = stats['total_sales'] ?? 0.0;
    _totalProfit = stats['total_profit'] ?? 0.0;
    _lowStockCount = stats['low_stock_count'] ?? 0.0;

    _recentTransactions = await DatabaseHelper.instance.getRecentTransactions();
    _topDefaulters = await DatabaseHelper.instance.getTopDefaulters();

    _isLoading = false;
    notifyListeners();
  }
}
