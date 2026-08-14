import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class AdminAuthService {
  static const String adminUserId = 'prime-admin';
  static const String adminPassword = '701865Say@';

  static Future<bool> isAdminLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_admin') ?? false;
  }

  static Future<void> setAdminLoggedIn(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_admin', isAdmin);
  }

  /// Verifies admin authority. If already logged in as admin returns true,
  /// otherwise prompts for admin password.
  static Future<bool> verifyAdmin(BuildContext context) async {
    final isAdmin = await isAdminLoggedIn();
    if (isAdmin) return true;

    final passCtrl = TextEditingController();
    String? errorMsg;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('এডমিন যাচাইকরণ'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'রিসাইকেল বিন ব্যবহার করতে অ্যাডমিনিস্ট্রেটর পাসওয়ার্ড লিখুন:',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'এডমিন পাসওয়ার্ড',
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (passCtrl.text == adminPassword) {
                  Navigator.pop(ctx, true);
                } else {
                  setDialogState(() => errorMsg = 'ভুল অ্যাডমিনিস্ট্রেটর পাসওয়ার্ড!');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('যাচাই করুন'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }
}
