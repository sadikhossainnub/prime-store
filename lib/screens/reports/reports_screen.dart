import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _customerData = [];
  bool _isLoading = true;

  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final monthly = await DatabaseHelper.instance.getMonthlyReport(_selectedYear, _selectedMonth);
    final customers = await DatabaseHelper.instance.getCustomerReport();
    setState(() {
      _monthlyData = monthly;
      _customerData = customers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('রিপোর্ট'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'মাসিক রিপোর্ট'),
            Tab(text: 'কাস্টমার রিপোর্ট'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildMonthlyTab(),
                  _buildCustomerTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildMonthlyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMonthSelector(),
        const SizedBox(height: 16),
        _buildMonthlySummaryCards(),
        const SizedBox(height: 16),
        if (_monthlyData.isNotEmpty) ...[_buildBarChart()] else const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text('এই মাসে কোনো লেনদেন নেই', style: TextStyle(color: Colors.white54)),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    final months = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      opacity: 0.08,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
              _loadData();
            },
          ),
          Text(
            '${months[_selectedMonth - 1]} $_selectedYear',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
              });
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCards() {
    double totalBaki = _monthlyData.fold(0, (s, e) => s + (e['baki'] as num? ?? 0));
    double totalPaid = _monthlyData.fold(0, (s, e) => s + (e['paid'] as num? ?? 0));
    return Row(
      children: [
        Expanded(child: _summaryCard('মোট বাকি', totalBaki, AppColors.error, Icons.money_off)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('মোট আদায়', totalPaid, AppColors.primary, Icons.account_balance_wallet)),
      ],
    );
  }

  Widget _summaryCard(String title, double amount, Color color, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 4),
          FittedBox(child: Text(_format.format(amount), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxY = _monthlyData.fold<double>(0, (m, e) {
      final b = (e['baki'] as num? ?? 0).toDouble();
      final p = (e['paid'] as num? ?? 0).toDouble();
      return [m, b, p].reduce((a, b) => a > b ? a : b);
    });

    return GlassCard(
      padding: const EdgeInsets.all(16),
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('দৈনিক বাকি vs আদায়', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            _legendDot(AppColors.error, 'বাকি'),
            const SizedBox(width: 16),
            _legendDot(AppColors.primary, 'আদায়'),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                barGroups: _monthlyData.asMap().entries.map((entry) {
                  final day = int.tryParse(entry.value['day'].toString().split('-').last) ?? entry.key + 1;
                  return BarChartGroupData(
                    x: day,
                    barRods: [
                      BarChartRodData(toY: (entry.value['baki'] as num? ?? 0).toDouble(), color: AppColors.error, width: 6, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: (entry.value['paid'] as num? ?? 0).toDouble(), color: AppColors.primary, width: 6, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ]);
  }

  Widget _buildCustomerTab() {
    if (_customerData.isEmpty) {
      return const Center(child: Text('কোনো কাস্টমার নেই', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customerData.length,
      itemBuilder: (context, index) {
        final c = _customerData[index];
        final baki = (c['total_baki'] as num? ?? 0).toDouble();
        final paid = (c['total_paid'] as num? ?? 0).toDouble();
        final due = baki - paid;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            opacity: 0.05,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    (c['name'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(c['phone'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('বাকি: ${_format.format(baki)}', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                        const SizedBox(width: 12),
                        Text('আদায়: ${_format.format(paid)}', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('বকেয়া', style: TextStyle(fontSize: 11, color: Colors.white54)),
                    Text(
                      _format.format(due),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: due > 0 ? AppColors.error : AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
