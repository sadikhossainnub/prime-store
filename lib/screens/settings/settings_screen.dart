import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/customer_provider.dart';
import '../../services/backup_service.dart';
import '../../services/license_service.dart';
import '../../services/admin_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'package:flutter/services.dart';
import '../auth/activation_screen.dart';
import 'recycle_bin_screen.dart';
import 'import_products_screen.dart';
import 'import_data_screen.dart';
import 'delete_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoBackup = false;
  String? _lastBackup;
  String? _driveEmail;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String _shopName = '';
  String _ownerName = '';
  String _customBackupPath = '';
  String? _deviceId;
  int _daysRemaining = 0;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final auto = await BackupService.isAutoBackupEnabled();
    final last = await BackupService.getLastBackupTime();
    final account = await BackupService.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final customPath = await BackupService.getCustomBackupDirPath();
    setState(() {
      _autoBackup = auto;
      _lastBackup = last;
      _driveEmail = account?.email;
      _shopName = prefs.getString('shop_name') ?? '';
      _ownerName = prefs.getString('owner_name') ?? '';
      _customBackupPath = customPath;
    });
    _loadLicenseInfo();
  }

  Future<void> _loadLicenseInfo() async {
    final devId = await LicenseService.getDeviceId();
    final days = await LicenseService.getDaysRemaining();
    final exp = await LicenseService.getExpiryDate();
    if (mounted) {
      setState(() {
        _deviceId = devId;
        _daysRemaining = days;
        _expiryDate = exp;
      });
    }
  }

  Future<void> _showShopInfoDialog() async {
    final shopCtrl = TextEditingController(text: _shopName);
    final ownerCtrl = TextEditingController(text: _ownerName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('দোকানের তথ্য'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: shopCtrl,
              decoration: const InputDecoration(
                labelText: 'দোকানের নাম',
                prefixIcon: Icon(Icons.store, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerCtrl,
              decoration: const InputDecoration(
                labelText: 'মালিকের নাম',
                prefixIcon: Icon(Icons.person, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('shop_name', shopCtrl.text.trim());
              await prefs.setString('owner_name', ownerCtrl.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              setState(() {
                _shopName = shopCtrl.text.trim();
                _ownerName = ownerCtrl.text.trim();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectDrive() async {
    try {
      final account = await BackupService.signIn();
      setState(() => _driveEmail = account?.email);
      if (account == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google সাইন-ইন বাতিল হয়েছে'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google সাইন-ইন ত্রুটি: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _disconnectDrive() async {
    await BackupService.signOut();
    setState(() => _driveEmail = null);
  }

  Future<void> _manualBackup() async {
    final verified = await AdminAuthService.verifyAdmin(context);
    if (!verified || !mounted) return;
    if (_driveEmail == null) {
      await _connectDrive();
      if (_driveEmail == null) return;
    }
    setState(() => _isBackingUp = true);
    final success = await BackupService.backupToDrive();
    final last = await BackupService.getLastBackupTime();
    setState(() { _isBackingUp = false; _lastBackup = last; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'ব্যাকআপ সফল হয়েছে ✓' : 'ব্যাকআপ ব্যর্থ হয়েছে'),
      backgroundColor: success ? AppColors.primary : AppColors.error,
    ));
  }

  Future<void> _restoreBackup() async {
    final verified = await AdminAuthService.verifyAdmin(context);
    if (!verified || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ডেটা পুনরুদ্ধার করবেন?'),
        content: const Text('Google Drive থেকে ডেটা পুনরুদ্ধার করলে বর্তমান সব ডেটা মুছে যাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('পুনরুদ্ধার করুন'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (_driveEmail == null) {
      await _connectDrive();
      if (_driveEmail == null) return;
    }
    setState(() => _isRestoring = true);
    final success = await BackupService.restoreFromDrive();
    setState(() => _isRestoring = false);
    if (!mounted) return;
    if (success) {
      context.read<DashboardProvider>().fetchStats();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'ডেটা পুনরুদ্ধার সফল। অ্যাপ রিস্টার্ট করুন।' : 'পুনরুদ্ধার ব্যর্থ হয়েছে'),
      backgroundColor: success ? AppColors.primary : AppColors.error,
    ));
  }

  Future<void> _changeBackupDirectory() async {
    final verified = await AdminAuthService.verifyAdmin(context);
    if (!verified || !mounted) return;

    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null || selectedDirectory.isEmpty) return;

      final success = await BackupService.setCustomBackupDir(selectedDirectory);
      if (mounted && success) {
        setState(() {
          _customBackupPath = selectedDirectory;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ নতুন ব্যাকআপ ডিরেক্টরি সেট হয়েছে:\n$selectedDirectory'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('পাথ সেট করতে সমস্যা হয়েছে: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportLocalExcelBackup() async {
    final verified = await AdminAuthService.verifyAdmin(context);
    if (!verified || !mounted) return;

    try {
      final path = await BackupService.exportLocalExcelBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel ব্যাকআপ তৈরি সফল হয়েছে ✓\nসেভ পাথ: $path'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ব্যাকআপ ব্যর্থ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportLocalDatabaseBackup() async {
    final verified = await AdminAuthService.verifyAdmin(context);
    if (!verified || !mounted) return;

    try {
      final path = await BackupService.exportLocalDatabaseBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SQLite DB ব্যাকআপ তৈরি সফল হয়েছে ✓\nসেভ পাথ: $path'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ব্যাকআপ ব্যর্থ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _restoreLocalDatabaseFile() async {
    final verified = await AdminAuthService.verifyAdmin(context);
    if (!verified || !mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      final file = File(path);
      final success = await BackupService.restoreFromLocalDbFile(file);

      if (!mounted) return;
      if (success) {
        context.read<DashboardProvider>().fetchStats();
        context.read<CustomerProvider>().fetchCustomers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ SQLite .db ফাইল থেকে ডেটা রিস্টোর সম্পন্ন হয়েছে!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('রিস্টোর করতে সমস্যা হয়েছে! বৈধ .db ফাইল সিলেক্ট করুন।'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('রিস্টোর ব্যর্থ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showHiddenBackupsDialog() async {
    final verified = await AdminAuthService.verifyAdmin(context);
    if (!verified || !mounted) return;

    final files = await BackupService.getHiddenBackupFiles();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('হাইড ফোল্ডারের ব্যাকআপসমূহ'),
        content: SizedBox(
          width: double.maxFinite,
          child: files.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('এখনো কোনো স্বয়ংক্রিয় ব্যাকআপ তৈরি হয়নি। (প্রতি ৩ দিন পর পর অটো তৈরি হবে)', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final f = files[index];
                    final name = p.basename(f.path);
                    final modified = DateFormat('dd MMM yyyy, hh:mm a').format(f.lastModifiedSync());
                    final size = (f.lengthSync() / 1024).toStringAsFixed(1);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description, color: AppColors.primary),
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('$modified | $size KB', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                        child: const Text('রিস্টোর', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await BackupService.restoreFromHiddenBackupFile(f);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? '✓ ব্যাকআপ ফাইল থেকে রিস্টোর সম্পন্ন হয়েছে!' : 'রিস্টোর করতে সমস্যা হয়েছে'),
                                backgroundColor: ok ? AppColors.primary : AppColors.error,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বন্ধ করুন', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('লগআউট করবেন?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('লগআউট'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('দোকানের তথ্য'),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.05,
              child: ListTile(
                leading: const Icon(Icons.store_rounded, color: AppColors.primary),
                title: Text(
                  _shopName.isNotEmpty ? _shopName : 'দোকানের নাম সেট করুন',
                  style: TextStyle(color: _shopName.isNotEmpty ? Colors.white : Colors.white38),
                ),
                subtitle: Text(
                  _ownerName.isNotEmpty ? 'মালিক: $_ownerName' : 'মালিকের নাম সেট করুন',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const Icon(Icons.edit, color: AppColors.primary, size: 18),
                onTap: _showShopInfoDialog,
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Google Drive ব্যাকআপ'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              opacity: 0.05,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_circle, color: AppColors.primary, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driveEmail ?? 'সংযুক্ত নয়',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _driveEmail != null ? Colors.white : Colors.white54,
                              ),
                            ),
                            Text(
                              _driveEmail != null ? 'Google Drive সংযুক্ত' : 'ব্যাকআপের জন্য সাইন-ইন করুন',
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _driveEmail != null ? _disconnectDrive : _connectDrive,
                        child: Text(
                          _driveEmail != null ? 'সংযোগ বিচ্ছিন্ন' : 'সংযুক্ত করুন',
                          style: TextStyle(color: _driveEmail != null ? AppColors.error : AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  if (_lastBackup != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Text(
                            'শেষ ব্যাকআপ: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_lastBackup!))}',
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _manualBackup,
                          icon: _isBackingUp
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_upload),
                          label: Text(_isBackingUp ? 'আপলোড হচ্ছে...' : 'এখনই ব্যাকআপ করুন'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isRestoring ? null : _restoreBackup,
                          icon: _isRestoring
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_download),
                          label: Text(_isRestoring ? 'লোড হচ্ছে...' : 'পুনরুদ্ধার করুন'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              opacity: 0.05,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('স্বয়ংক্রিয় ব্যাকআপ'),
                subtitle: const Text('প্রতিদিন একবার Google Drive-এ ব্যাকআপ', style: TextStyle(fontSize: 12, color: Colors.white54)),
                value: _autoBackup,
                  activeThumbColor: AppColors.primary,
                onChanged: (val) async {
                  await BackupService.setAutoBackup(val);
                  setState(() => _autoBackup = val);
                },
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('লোকাল ফাইল ব্যাকআপ (Admin Only)'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              opacity: 0.05,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_open_rounded, color: Colors.purpleAccent, size: 22),
                    ),
                    title: const Text('ব্যাকআপ ফোল্ডার লোকেশন সেট করুন'),
                    subtitle: Text(
                      _customBackupPath.isNotEmpty ? _customBackupPath : 'ফোল্ডার নির্ধারণ করতে ট্যাপ করুন',
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    trailing: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                    onTap: _changeBackupDirectory,
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_rounded, color: AppColors.primary, size: 22),
                    ),
                    title: const Text('Excel ব্যাকআপ তৈরি করুন (.xlsx)'),
                    subtitle: const Text('কাস্টমার, বাকি ও পেমেন্টের Excel ব্যাকআপ ফাইল ডাউনলোডস ফোল্ডারে সেভ হবে', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                    onTap: _exportLocalExcelBackup,
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storage_rounded, color: AppColors.secondary, size: 22),
                    ),
                    title: const Text('SQLite ডেটাবেস ব্যাকআপ (.db)'),
                    subtitle: const Text('সম্পূর্ণ ডেটাবেসের কপি ডাউনলোডস ফোল্ডারে সেভ হবে', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                    onTap: _exportLocalDatabaseBackup,
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_backup_restore_rounded, color: Colors.cyan, size: 22),
                    ),
                    title: const Text('SQLite ডেটাবেস (.db) ফাইল রিস্টোর করুন'),
                    subtitle: const Text('ফোন থেকে যেকোনো .db ব্যাকআপ ফাইল সিলেক্ট করে সরাসরি রিস্টোর করুন', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                    onTap: _restoreLocalDatabaseFile,
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_special_rounded, color: Colors.amber, size: 22),
                    ),
                    title: const Text('স্বয়ংক্রিয় ৩-দিনের লোকাল ব্যাকআপসমূহ'),
                    subtitle: const Text('হাইড ফোল্ডারে থাকা ৩ দিন পর পর তৈরি হওয়া অটো DB ব্যাকআপসমূহ দেখুন ও রিস্টোর করুন', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                    onTap: _showHiddenBackupsDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('লাইসেন্স তথ্য'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              opacity: 0.05,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('লাইসেন্স স্ট্যাটাস: সক্রিয়', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 2),
                            Text(
                              _expiryDate != null
                                  ? 'মেয়াদের তারিখ: ${DateFormat('dd MMM yyyy').format(_expiryDate!)} ($_daysRemaining দিন বাকি)'
                                  : 'লাইসেন্স সক্রিয় আছে',
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Device ID:', style: TextStyle(fontSize: 12, color: Colors.white54)),
                            Text(
                              _deviceId ?? '---',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                        tooltip: 'Device ID কপি করুন',
                        onPressed: () {
                          if (_deviceId != null) {
                            Clipboard.setData(ClipboardData(text: _deviceId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Device ID কপি হয়েছে!'), backgroundColor: AppColors.primary),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivationScreen(
                              onActivated: () {
                                Navigator.pop(context);
                                _loadLicenseInfo();
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.key_rounded, size: 18),
                      label: const Text('নতুন Activation Key লিখুন'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('ডেটা ম্যানেজমেন্ট'),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.05,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dataset_rounded, color: AppColors.secondary, size: 20),
                ),
                title: const Text('Excel / CSV ডেটা রিস্টোর'),
                subtitle: const Text('কাস্টমার, বাকি ও পেমেন্ট মার্জ (Admin)', style: TextStyle(fontSize: 12, color: Colors.white54)),
                trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                onTap: () async {
                  final verified = await AdminAuthService.verifyAdmin(context);
                  if (!verified || !mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportDataScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.05,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 20),
                ),
                title: const Text('পণ্য ও স্টক ইমপোর্ট'),
                subtitle: const Text('Excel / CSV থেকে পণ্য যোগ (Admin)', style: TextStyle(fontSize: 12, color: Colors.white54)),
                trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                onTap: () async {
                  final verified = await AdminAuthService.verifyAdmin(context);
                  if (!verified || !mounted) return;
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportProductsScreen()),
                  );
                  if (result == true && mounted) {
                    context.read<DashboardProvider>().fetchStats();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('পণ্য ইমপোর্ট সফল হয়েছে ✓'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('সিস্টেম ও সিকিউরিটি'),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.05,
              child: ListTile(
                leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.accent),
                title: const Text('রিসাইকেল বিন (Recycle Bin)'),
                subtitle: const Text('মুছে ফেলা আইটেম পুনঃরুদ্ধার (Admin)', style: TextStyle(fontSize: 12, color: Colors.white54)),
                trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                onTap: () async {
                  final verified = await AdminAuthService.verifyAdmin(context);
                  if (verified && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.05,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
                ),
                title: const Text('ডেটা মুছে ফেলুন', style: TextStyle(color: AppColors.error)),
                subtitle: const Text('সব ডেটা মুছুন (Admin)', style: TextStyle(fontSize: 12, color: Colors.white54)),
                trailing: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                onTap: () async {
                  final verified = await AdminAuthService.verifyAdmin(context);
                  if (verified && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteDataScreen()));
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('অ্যাকাউন্ট'),
            GlassCard(
              padding: EdgeInsets.zero,
              opacity: 0.05,
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('লগআউট', style: TextStyle(color: AppColors.error)),
                subtitle: const Text('অ্যাপ থেকে বের হন', style: TextStyle(fontSize: 12, color: Colors.white54)),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w600)),
    );
  }
}
