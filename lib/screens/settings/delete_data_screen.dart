import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DeleteDataScreen extends StatefulWidget {
  const DeleteDataScreen({super.key});

  @override
  State<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends State<DeleteDataScreen> {
  Map<String, int> _counts = {};
  bool _isLoading = true;
  String? _deletingKey; // Which category is currently being deleted

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    final counts = await DatabaseHelper.instance.getAllDataCounts();
    if (mounted) {
      setState(() {
        _counts = counts;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndDelete({
    required String key,
    required String title,
    required String description,
    required String warningText,
    required Future<void> Function() deleteAction,
  }) async {
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningText,
                      style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('হ্যাঁ, মুছে ফেলুন'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    // Second confirmation with text input for dangerous actions
    final confirmCtrl = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isValid = confirmCtrl.text == 'DELETE';
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('চূড়ান্ত নিশ্চিতকরণ', style: TextStyle(color: AppColors.error)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।\nনিশ্চিত করতে নিচে DELETE লিখুন:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmCtrl,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: AppColors.error,
                  ),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15), letterSpacing: 3),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  disabledBackgroundColor: AppColors.error.withValues(alpha: 0.2),
                ),
                child: const Text('মুছে ফেলুন'),
              ),
            ],
          );
        },
      ),
    );
    if (secondConfirm != true || !mounted) return;

    // Execute delete
    setState(() => _deletingKey = key);
    try {
      await deleteAction();
      if (mounted) {
        context.read<DashboardProvider>().fetchStats();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title সফল হয়েছে ✓'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ত্রুটি: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    setState(() => _deletingKey = null);
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ডেটা মুছে ফেলুন'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Warning banner
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    opacity: 0.08,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'সতর্কতা!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.error,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'ডেটা মুছে ফেললে আর ফেরত পাওয়া যাবে না। মুছার আগে ব্যাকআপ নেওয়ার পরামর্শ দেওয়া হচ্ছে।',
                                style: TextStyle(fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle('আলাদা আলাদা মুছুন'),

                  // Individual delete options
                  _deleteOptionTile(
                    key: 'products',
                    icon: Icons.inventory_2_rounded,
                    iconColor: const Color(0xFF4CAF50),
                    title: 'সকল পণ্য মুছুন',
                    subtitle: '${_counts['products'] ?? 0} টি পণ্য',
                    description: 'সকল পণ্য, স্টক তথ্য, এবং সংশ্লিষ্ট বিক্রয়/ক্রয়ের আইটেম লাইন মুছে যাবে।',
                    warning: 'বিক্রয় ও ক্রয়ের আইটেম ডিটেইলও মুছে যাবে!',
                    onDelete: () => DatabaseHelper.instance.deleteAllProducts(),
                  ),
                  const SizedBox(height: 8),
                  _deleteOptionTile(
                    key: 'customers',
                    icon: Icons.people_rounded,
                    iconColor: const Color(0xFF2196F3),
                    title: 'সকল কাস্টমার মুছুন',
                    subtitle: '${_counts['customers'] ?? 0} জন কাস্টমার',
                    description: 'সকল কাস্টমার, তাদের বাকির হিসাব এবং পেমেন্ট রেকর্ড মুছে যাবে।',
                    warning: 'সকল বাকি ও পেমেন্ট রেকর্ডও মুছে যাবে!',
                    onDelete: () => DatabaseHelper.instance.deleteAllCustomers(),
                  ),
                  const SizedBox(height: 8),
                  _deleteOptionTile(
                    key: 'sales',
                    icon: Icons.point_of_sale_rounded,
                    iconColor: const Color(0xFFFF9800),
                    title: 'সকল বিক্রয় মুছুন',
                    subtitle: '${_counts['sales'] ?? 0} টি বিক্রয়',
                    description: 'সকল বিক্রয় রেকর্ড এবং বিক্রয়ের আইটেম ডিটেইল মুছে যাবে।',
                    warning: 'বিক্রয়ের সাথে সম্পর্কিত সকল ডেটা মুছে যাবে!',
                    onDelete: () => DatabaseHelper.instance.deleteAllSales(),
                  ),
                  const SizedBox(height: 8),
                  _deleteOptionTile(
                    key: 'purchases',
                    icon: Icons.shopping_cart_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    title: 'সকল ক্রয় মুছুন',
                    subtitle: '${_counts['purchases'] ?? 0} টি ক্রয়',
                    description: 'সকল ক্রয় রেকর্ড এবং ক্রয়ের আইটেম ডিটেইল মুছে যাবে।',
                    warning: 'ক্রয়ের সাথে সম্পর্কিত সকল ডেটা মুছে যাবে!',
                    onDelete: () => DatabaseHelper.instance.deleteAllPurchases(),
                  ),
                  const SizedBox(height: 8),
                  _deleteOptionTile(
                    key: 'suppliers',
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF00BCD4),
                    title: 'সকল সাপ্লায়ার মুছুন',
                    subtitle: '${_counts['suppliers'] ?? 0} জন সাপ্লায়ার',
                    description: 'সকল সাপ্লায়ারের তথ্য মুছে যাবে।',
                    warning: 'সাপ্লায়ার ডেটা মুছে ফেলা হবে!',
                    onDelete: () => DatabaseHelper.instance.deleteAllSuppliers(),
                  ),
                  const SizedBox(height: 8),
                  _deleteOptionTile(
                    key: 'transactions',
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFFFF5722),
                    title: 'সকল বাকি/পেমেন্ট মুছুন',
                    subtitle: '${_counts['transactions'] ?? 0} টি বাকি, ${_counts['payments'] ?? 0} টি পেমেন্ট',
                    description: 'সকল বাকির হিসাব এবং পেমেন্ট রেকর্ড মুছে যাবে। কাস্টমার থাকবে।',
                    warning: 'বাকি ও পেমেন্টের সকল হিসাব শূন্য হয়ে যাবে!',
                    onDelete: () => DatabaseHelper.instance.deleteAllTransactions(),
                  ),

                  const SizedBox(height: 32),
                  _sectionTitle('বিপদজনক জোন'),

                  // Delete ALL data
                  GlassCard(
                    padding: EdgeInsets.zero,
                    opacity: 0.05,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _deletingKey == 'all'
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                                )
                              : const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 26),
                        ),
                        title: const Text(
                          'সব ডেটা মুছে ফেলুন',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          _getTotalCount(),
                          style: const TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.error, size: 16),
                        onTap: _deletingKey != null
                            ? null
                            : () => _confirmAndDelete(
                                  key: 'all',
                                  title: 'সব ডেটা মুছে ফেলুন',
                                  description:
                                      'এটি অ্যাপের সকল ডেটা সম্পূর্ণভাবে মুছে ফেলবে:\n\n• সকল পণ্য ও স্টক\n• সকল কাস্টমার ও বাকি\n• সকল বিক্রয় ও ক্রয়\n• সকল সাপ্লায়ার\n• রিসাইকেল বিন',
                                  warningText: 'এই কাজটি অপরিবর্তনীয়! সব ডেটা চিরতরে হারিয়ে যাবে!',
                                  deleteAction: () => DatabaseHelper.instance.deleteAllData(),
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _deleteOptionTile({
    required String key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
    required String warning,
    required Future<void> Function() onDelete,
  }) {
    final isDeleting = _deletingKey == key;
    return GlassCard(
      padding: EdgeInsets.zero,
      opacity: 0.05,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isDeleting
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                )
              : Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
        onTap: _deletingKey != null
            ? null
            : () => _confirmAndDelete(
                  key: key,
                  title: title,
                  description: description,
                  warningText: warning,
                  deleteAction: onDelete,
                ),
      ),
    );
  }

  String _getTotalCount() {
    final total = _counts.values.fold<int>(0, (sum, v) => sum + v);
    return 'মোট $total টি রেকর্ড মুছে যাবে';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w600),
      ),
    );
  }
}
