import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'supplier_detail_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().fetchSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সরবরাহকারী'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
            onPressed: () => _showAddSheet(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: GlassCard(
                padding: EdgeInsets.zero,
                opacity: 0.1,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'সরবরাহকারী খুঁজুন...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final provider = context.watch<SupplierProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final suppliers = provider.searchSuppliers(_searchQuery);
    if (suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('কোনো সরবরাহকারী নেই', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('যোগ করুন'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    final format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final s = suppliers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplier: s)),
            ).then((_) => context.read<SupplierProvider>().fetchSuppliers()),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              opacity: 0.05,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    child: Text(s.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(s.phone,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white54)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('বকেয়া', style: TextStyle(fontSize: 11, color: Colors.white54)),
                      Text(
                        format.format(s.totalDue),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: s.totalDue > 0 ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    color: AppColors.surface,
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    onSelected: (v) {
                      if (v == 'edit') _showAddSheet(supplier: s);
                      if (v == 'delete') _confirmDelete(s);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('সম্পাদনা')
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, color: AppColors.error, size: 18),
                            SizedBox(width: 8),
                            Text('মুছুন')
                          ])),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddSheet({Supplier? supplier}) {
    final nameCtrl = TextEditingController(text: supplier?.name);
    final phoneCtrl = TextEditingController(text: supplier?.phone);
    final addressCtrl = TextEditingController(text: supplier?.address);
    final isEdit = supplier != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(isEdit ? 'সরবরাহকারী সম্পাদনা' : 'নতুন সরবরাহকারী',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _sheetField(nameCtrl, 'নাম *', Icons.person_outline),
              const SizedBox(height: 12),
              _sheetField(phoneCtrl, 'ফোন *', Icons.phone_outlined,
                  type: TextInputType.phone),
              const SizedBox(height: 12),
              _sheetField(addressCtrl, 'ঠিকানা (অপশনাল)', Icons.location_on_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('নাম ও ফোন আবশ্যক'),
                          backgroundColor: AppColors.error));
                      return;
                    }
                    final provider = ctx.read<SupplierProvider>();
                    if (isEdit) {
                      await provider.updateSupplier(Supplier(
                        id: supplier.id,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        createdAt: supplier.createdAt,
                      ));
                    } else {
                      await provider.addSupplier(nameCtrl.text.trim(), phoneCtrl.text.trim(),
                          address: addressCtrl.text.trim());
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text(isEdit ? 'আপডেট করুন' : 'সংরক্ষণ করুন'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.background.withValues(alpha: 0.5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  void _confirmDelete(Supplier supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('সরবরাহকারী মুছবেন?'),
        content: Text('${supplier.name} রিসাইকেল বিন-এ স্থানান্তর করা হবে। এডমিন পরবর্তীতে তা পুনঃরুদ্ধার করতে পারবেন।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await context.read<SupplierProvider>().deleteSupplier(supplier.id!);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
  }
}
