import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'customer_detail_screen.dart';
import 'package:intl/intl.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('কাস্টমার লিস্ট'),
        actions: [
          IconButton(
            onPressed: () => _showAddCustomerSheet(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildCustomerList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassCard(
        padding: EdgeInsets.zero,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(12),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'কাস্টমার খুঁজুন (নাম বা ফোন)',
            prefixIcon: Icon(Icons.search, color: AppColors.primary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    final customerProvider = context.watch<CustomerProvider>();
    final customers = customerProvider.searchCustomers(_searchQuery);

    if (customerProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (customers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('কোনো কাস্টমার পাওয়া যায়নি', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: customers.length,
      itemBuilder: (itemContext, index) {
        final customer = customers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => Navigator.push(
              itemContext,
              MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: customer)),
            ).then((_) {
              if (itemContext.mounted) itemContext.read<CustomerProvider>().fetchCustomers();
            }),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              opacity: 0.05,
              child: Row(
                children: [
                  // Serial number
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  _buildCustomerAvatar(customer),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(customer.phone, style: const TextStyle(fontSize: 14, color: Colors.white54)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('মোট বাকি', style: TextStyle(fontSize: 12, color: Colors.white54)),
                      Text(
                        format.format(customer.totalBaki),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: customer.totalBaki > 0 ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    color: AppColors.surface,
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    onSelected: (value) {
                      if (value == 'edit') _showAddCustomerSheet(itemContext, customer: customer);
                      if (value == 'delete') _confirmDelete(itemContext, customer);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: AppColors.primary, size: 18), SizedBox(width: 8), Text('তথ্য সম্পাদনা')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: AppColors.error, size: 18), SizedBox(width: 8), Text('মুছে ফেলুন')])),
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

  /// Builds a CircleAvatar with the customer's photo or a letter fallback.
  Widget _buildCustomerAvatar(Customer customer, {double radius = 22}) {
    if (customer.photoPath != null && customer.photoPath!.isNotEmpty) {
      final file = File(customer.photoPath!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      child: Text(
        customer.name[0].toUpperCase(),
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  // ─── Add / Edit Customer Bottom Sheet ────────────────────────────────

  void _showAddCustomerSheet(BuildContext context, {Customer? customer}) {
    final nameController = TextEditingController(text: customer?.name);
    final phoneController = TextEditingController(text: customer?.phone);
    final addressController = TextEditingController(text: customer?.address);
    final isEdit = customer != null;
    String? selectedPhotoPath = customer?.photoPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        isEdit ? 'কাস্টমার সম্পাদনা' : 'নতুন কাস্টমার যোগ করুন',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // ── Photo Picker ──
                      Center(
                        child: GestureDetector(
                          onTap: () => _showPhotoOptions(ctx, selectedPhotoPath, (path) {
                            setSheetState(() => selectedPhotoPath = path);
                          }),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                backgroundImage: selectedPhotoPath != null && selectedPhotoPath!.isNotEmpty
                                    ? FileImage(File(selectedPhotoPath!))
                                    : null,
                                child: selectedPhotoPath == null || selectedPhotoPath!.isEmpty
                                    ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text('ছবি যোগ করুন', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                      const SizedBox(height: 20),

                      // ── Name Field ──
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'নাম *',
                          prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Phone Field with Contact Picker ──
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'ফোন নম্বর *',
                                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
                                filled: true,
                                fillColor: AppColors.background.withValues(alpha: 0.5),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Contact Picker Button
                          Material(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _pickContact(ctx, nameController, phoneController, setSheetState),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                child: const Icon(Icons.contacts_rounded, color: AppColors.primary, size: 28),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Address Field ──
                      TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'ঠিকানা (অপশনাল)',
                          prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Action Buttons ──
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _saveCustomer(
                                ctx,
                                nameController: nameController,
                                phoneController: phoneController,
                                addressController: addressController,
                                photoPath: selectedPhotoPath,
                                existingCustomer: customer,
                              ),
                              icon: Icon(isEdit ? Icons.check : Icons.save),
                              label: Text(isEdit ? 'আপডেট করুন' : 'সংরক্ষণ করুন'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Contact Picker ──────────────────────────────────────────────────

  Future<void> _pickContact(
    BuildContext ctx,
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    StateSetter setSheetState,
  ) async {
    try {
      // Request read permission
      final permStatus = await FlutterContacts.permissions.request(PermissionType.read);
      if (permStatus != PermissionStatus.granted && permStatus != PermissionStatus.limited) {
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('কন্টাক্ট অনুমতি প্রয়োজন। সেটিংস থেকে অনুমতি দিন।'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Open native contact picker
      final contactId = await FlutterContacts.native.showPicker();
      if (contactId == null) return;

      // Fetch full contact with phone property
      final fullContact = await FlutterContacts.get(
        contactId,
        properties: {ContactProperty.phone},
      );
      if (fullContact == null) return;

      setSheetState(() {
        if (fullContact.displayName != null && fullContact.displayName!.isNotEmpty && nameCtrl.text.isEmpty) {
          nameCtrl.text = fullContact.displayName!;
        }
        if (fullContact.phones.isNotEmpty) {
          // Clean phone number (remove spaces, dashes)
          String phone = fullContact.phones.first.number
              .replaceAll(RegExp(r'[\s\-\(\)]'), '');
          phoneCtrl.text = phone;
        }
      });
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('কন্টাক্ট লোড করতে সমস্যা হয়েছে: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ─── Photo Picker ────────────────────────────────────────────────────

  void _showPhotoOptions(BuildContext ctx, String? currentPath, ValueChanged<String?> onPicked) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (innerCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('ছবি নির্বাচন করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('ক্যামেরা দিয়ে তুলুন'),
                onTap: () {
                  Navigator.pop(innerCtx);
                  _pickImage(ctx, ImageSource.camera, onPicked);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.purple),
                ),
                title: const Text('গ্যালারি থেকে বাছুন'),
                onTap: () {
                  Navigator.pop(innerCtx);
                  _pickImage(ctx, ImageSource.gallery, onPicked);
                },
              ),
              if (currentPath != null && currentPath.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete, color: AppColors.error),
                  ),
                  title: const Text('ছবি সরান'),
                  onTap: () {
                    Navigator.pop(innerCtx);
                    onPicked(null);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(BuildContext ctx, ImageSource source, ValueChanged<String?> onPicked) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked == null) return;

      // Copy to app's permanent directory
      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory(p.join(appDir.path, 'customer_photos'));
      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }
      final fileName = 'customer_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
      final savedFile = await File(picked.path).copy(p.join(photoDir.path, fileName));
      onPicked(savedFile.path);
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('ছবি নেওয়া হয়নি: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // ─── Save / Update Customer ──────────────────────────────────────────

  Future<void> _saveCustomer(
    BuildContext ctx, {
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required TextEditingController addressController,
    String? photoPath,
    Customer? existingCustomer,
  }) async {
    if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('নাম ও ফোন নম্বর আবশ্যক'), backgroundColor: AppColors.error),
      );
      return;
    }

    final provider = ctx.read<CustomerProvider>();
    if (existingCustomer != null) {
      await provider.updateCustomer(Customer(
        id: existingCustomer.id,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        photoPath: photoPath,
        createdAt: existingCustomer.createdAt,
      ));
    } else {
      await provider.addCustomer(
        nameController.text.trim(),
        phoneController.text.trim(),
        address: addressController.text.trim(),
        photoPath: photoPath,
      );
    }
    if (!ctx.mounted) return;
    ctx.read<DashboardProvider>().fetchStats();
    Navigator.pop(ctx);
  }

  // ─── Delete Confirmation ─────────────────────────────────────────────

  void _confirmDelete(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('কাস্টমার মুছবেন?'),
        content: Text('${customer.name} এর সব তথ্য ও লেনদেন রিসাইকেল বিন-এ স্থানান্তর করা হবে। এডমিন পরবর্তীতে তা পুনঃরুদ্ধার করতে পারবেন।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final provider = ctx.read<CustomerProvider>();
              await provider.deleteCustomer(customer.id!);
              if (!ctx.mounted) return;
              ctx.read<DashboardProvider>().fetchStats();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('${customer.name} মুছে ফেলা হয়েছে'), backgroundColor: AppColors.error),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
  }
}
