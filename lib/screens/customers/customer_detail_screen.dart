import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/sms_service.dart';
import '../../services/whatsapp_service.dart';
import 'package:intl/intl.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _currentCustomer;
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final txProvider = context.read<TransactionProvider>();
    final txs = await txProvider.getTransactions(_currentCustomer.id!);
    final payments = await txProvider.getPayments(_currentCustomer.id!);
    
    // Combine and sort by date
    final List<dynamic> combined = [...txs, ...payments];
    combined.sort((a, b) => (b.date as DateTime).compareTo(a.date as DateTime));
    
    // Refresh customer to get updated total_baki
    if (!mounted) return;
    final updatedCustomer = await context.read<CustomerProvider>().getCustomer(_currentCustomer.id!);

    if (mounted) {
      setState(() {
        _history = combined;
        if (updatedCustomer != null) _currentCustomer = updatedCustomer;
        _isLoading = false;
      });
      // Also refresh dashboard in background
      context.read<DashboardProvider>().fetchStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCustomer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.primary),
            onPressed: () => _showEditDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            _buildCustomerHeader(format),
            _buildActionButtons(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('লেনদেনের ইতিহাস', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(child: _buildHistoryList(format)),
          ],
        ),
      ),
      floatingActionButton: _buildFABs(),
    );
  }

  Widget _buildDetailAvatar() {
    if (_currentCustomer.photoPath != null && _currentCustomer.photoPath!.isNotEmpty) {
      final file = File(_currentCustomer.photoPath!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: 30,
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.primary,
      child: Text(
        _currentCustomer.name[0].toUpperCase(),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildCustomerHeader(NumberFormat format) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _buildDetailAvatar(),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentCustomer.phone, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  if (_currentCustomer.address != null && _currentCustomer.address!.isNotEmpty)
                    Text(_currentCustomer.address!, style: const TextStyle(fontSize: 14, color: Colors.white54)),
                  const SizedBox(height: 8),
                  const Text('মোট বাকি পাওনা', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  Text(
                    format.format(_currentCustomer.totalBaki),
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      color: _currentCustomer.totalBaki > 0 ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.sms_rounded,
              label: 'SMS পাঠান',
              color: Colors.blue,
              onTap: () => SmsService.sendBakiReminder(_currentCustomer.phone, _currentCustomer.totalBaki),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.chat_bubble_rounded,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => WhatsappService.sendBakiReminder(_currentCustomer.phone, _currentCustomer.totalBaki),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        opacity: 0.1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(NumberFormat format) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) return const Center(child: Text('কোনো লেনদেন পাওয়া যায়নি', style: TextStyle(color: Colors.white24)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final isBaki = item is BakiTransaction;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            opacity: 0.05,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isBaki ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBaki ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    color: isBaki ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBaki ? 'বাকি নিয়েছেন' : 'আদায় হয়েছে',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a', 'bn_BD').format(item.date),
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      if (isBaki && item.description != null && item.description!.isNotEmpty)
                        Text(item.description!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      if (!isBaki && item.note != null && item.note!.isNotEmpty)
                        Text(item.note!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                Text(
                  (isBaki ? '+ ' : '- ') + format.format(item.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBaki ? AppColors.error : AppColors.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDeleteSingleTransaction(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteSingleTransaction(dynamic item) {
    final isBaki = item is BakiTransaction;
    final title = isBaki ? 'বাকি লেনদেন মুছবেন?' : 'পেমেন্ট/আদায় মুছবেন?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(
          'এই লেনদেনটি (৳${item.amount}) মুছে ফেলা হবে এবং রিসাইকেল বিন-এ স্থানান্তর করা হবে। কাস্টমারের মোট বাকি পুনঃহিসাব করা হবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final txProvider = context.read<TransactionProvider>();
              if (isBaki) {
                if (item.id != null) {
                  await txProvider.deleteTransaction(item.id!);
                }
              } else {
                if (item.id != null) {
                  await txProvider.deletePayment(item.id!);
                }
              }
              if (!mounted) return;
              await _fetchHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('লেনদেনটি রিসাইকেল বিন-এ স্থানান্তর করা হয়েছে'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
  }

  Widget _buildFABs() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'add_baki',
          onPressed: () => _showTransactionDialog(context, true),
          backgroundColor: AppColors.error,
          icon: const Icon(Icons.remove),
          label: const Text('বাকি দিন'),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'add_payment',
          onPressed: () => _showTransactionDialog(context, false),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add),
          label: const Text('আদায় করুন'),
        ),
      ],
    );
  }

  void _showPaymentNotificationDialog(double paidAmount, double remainingDue) {
    final title = remainingDue <= 0 ? 'বাকি পরিশোধ সম্পন্ন' : 'আংশিক আদায় হয়েছে';
    final message = remainingDue <= 0
        ? 'ধন্যবাদ! গ্রাহকের বাকি সম্পূর্ণ পরিশোধ হয়েছে। SMS বা WhatsApp-এ জানান।'
        : 'গ্রাহক কিছু টাকা পরিশোধ করেছে। বাকি এখন ৳${NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD').format(remainingDue)}। SMS বা WhatsApp-এ জানান।';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SmsService.sendPaymentNotification(_currentCustomer.phone, paidAmount, remainingDue);
            },
            child: const Text('SMS পাঠান'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await WhatsappService.sendPaymentNotification(_currentCustomer.phone, paidAmount, remainingDue);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameController = TextEditingController(text: _currentCustomer.name);
    final phoneController = TextEditingController(text: _currentCustomer.phone);
    final addressController = TextEditingController(text: _currentCustomer.address);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('কাস্টমার সম্পাদনা'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'নাম')),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'ফোন নম্বর'),
            ),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'ঠিকানা')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await context.read<CustomerProvider>().updateCustomer(Customer(
                id: _currentCustomer.id,
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                address: addressController.text.trim(),
                photoPath: _currentCustomer.photoPath,
                createdAt: _currentCustomer.createdAt,
              ));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _fetchHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('আপডেট করুন'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('কাস্টমার মুছবেন?'),
        content: Text('${_currentCustomer.name} এর সব তথ্য ও লেনদেন রিসাইকেল বিন-এ স্থানান্তর করা হবে। এডমিন পরবর্তীতে তা পুনঃরুদ্ধার করতে পারবেন।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await context.read<CustomerProvider>().deleteCustomer(_currentCustomer.id!);
              if (!ctx.mounted) return;
              context.read<DashboardProvider>().fetchStats();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(BuildContext context, bool isBaki) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isBaki ? 'বাকি যোগ করুন' : 'টাকা জমা নিন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'টাকার পরিমাণ (প্রয়োজনীয়)', suffixText: '৳'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent),
              autofocus: true,
            ),
            TextField(
              controller: noteController,
              decoration: InputDecoration(labelText: isBaki ? 'বিবরণ (কি নিলেন?)' : 'নোট'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                final previousDue = _currentCustomer.totalBaki;
                final txProvider = context.read<TransactionProvider>();
                if (isBaki) {
                  await txProvider.addBaki(_currentCustomer.id!, amount, noteController.text);
                } else {
                  await txProvider.addPayment(_currentCustomer.id!, amount, noteController.text);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                await _fetchHistory();
                if (!isBaki && context.mounted) {
                  final remainingDue = (previousDue - amount).clamp(0, double.infinity).toDouble();
                  _showPaymentNotificationDialog(amount, remainingDue);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isBaki ? AppColors.error : AppColors.primary),
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );
  }
}
