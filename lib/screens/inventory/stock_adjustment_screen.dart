import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StockAdjustmentScreen extends StatefulWidget {
  final Product product;
  const StockAdjustmentScreen({super.key, required this.product});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'add'; // 'add' or 'remove'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('স্টক সমন্বয়')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              opacity: 0.08,
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.product.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        'বর্তমান স্টক: ${widget.product.currentStock} ${widget.product.unit}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('সমন্বয়ের ধরন', style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _typeButton('যোগ করুন', 'add', AppColors.primary, Icons.add_circle_outline)),
                const SizedBox(width: 12),
                Expanded(child: _typeButton('বাদ দিন', 'remove', AppColors.error, Icons.remove_circle_outline)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('পরিমাণ *', style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 6),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.08,
              child: TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.accent),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: widget.product.unit,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.08,
              child: TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'কারণ (অপশনাল)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                  prefixIcon: Icon(Icons.note_outlined, color: AppColors.primary),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'add' ? AppColors.primary : AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('সংরক্ষণ করুন',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String label, String value, Color color, IconData icon) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        opacity: selected ? 0.2 : 0.05,
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.white38, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.white38,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সঠিক পরিমাণ লিখুন'), backgroundColor: AppColors.error));
      return;
    }
    final delta = _type == 'add' ? qty : -qty;
    await context.read<InventoryProvider>().adjustStock(widget.product.id!, delta);
    if (!mounted) return;
    Navigator.pop(context);
  }
}
