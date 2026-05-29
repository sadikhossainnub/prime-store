import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

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
    setState(() {
      _autoBackup = auto;
      _lastBackup = last;
      _driveEmail = account?.email;
      _shopName = prefs.getString('shop_name') ?? '';
      _ownerName = prefs.getString('owner_name') ?? '';
    });
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
    final account = await BackupService.signIn();
    setState(() => _driveEmail = account?.email);
    if (account == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google সাইন-ইন বাতিল হয়েছে'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _disconnectDrive() async {
    await BackupService.signOut();
    setState(() => _driveEmail = null);
  }

  Future<void> _manualBackup() async {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'ডেটা পুনরুদ্ধার সফল। অ্যাপ রিস্টার্ট করুন।' : 'পুনরুদ্ধার ব্যর্থ হয়েছে'),
      backgroundColor: success ? AppColors.primary : AppColors.error,
    ));
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
