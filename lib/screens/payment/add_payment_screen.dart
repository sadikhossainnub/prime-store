import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class AddPaymentScreen extends StatefulWidget {
  const AddPaymentScreen({super.key});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  Customer? _selectedCustomer;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<CustomerProvider>().fetchCustomers();
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;

    return Scaffold(
      appBar: AppBar(title: const Text('টাকা আদায় করুন')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('কাস্টমার নির্বাচন করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildCustomerSelector(customers),
              const SizedBox(height: 20),
              const Text('টাকার পরিমাণ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    prefixText: '৳ ',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('নোট (অপশনাল)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'কোনো বিশেষ নোট?',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _savePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('সংরক্ষণ করুন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSelector(List<Customer> customers) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Customer>(
          value: _selectedCustomer,
          isExpanded: true,
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('কাস্টমার খুঁজুন'),
          ),
          dropdownColor: AppColors.surface,
          items: customers.map((c) => DropdownMenuItem(
            value: c,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${c.name} (${c.phone})'),
            ),
          )).toList(),
          onChanged: (val) => setState(() => _selectedCustomer = val),
        ),
      ),
    );
  }

  void _savePayment() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অনুগ্রহ করে কাস্টমার নির্বাচন করুন')));
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক টাকার পরিমাণ লিখুন')));
      return;
    }

    await context.read<TransactionProvider>().addPayment(
      _selectedCustomer!.id!,
      amount,
      _noteController.text,
    );
    
    if (!mounted) return;
    Navigator.pop(context);
  }
}
