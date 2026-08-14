import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'providers/customer_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/sales_provider.dart';
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/activation_screen.dart';
import 'services/backup_service.dart';
import 'services/notification_service.dart';
import 'services/license_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('bn_BD', null);

  await NotificationService.init();
  await NotificationService.scheduleMonthEndReminder();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final licenseStatus = await LicenseService.checkLicense();
  if (isLoggedIn) {
    BackupService.autoBackupIfNeeded();
    BackupService.autoLocalBackupEvery3Days();
  }
  runApp(AmerDokanApp(isLoggedIn: isLoggedIn, licenseStatus: licenseStatus));
}

class AmerDokanApp extends StatelessWidget {
  final bool isLoggedIn;
  final LicenseStatus licenseStatus;
  const AmerDokanApp({super.key, required this.isLoggedIn, required this.licenseStatus});

  @override
  Widget build(BuildContext context) {
    // Show activation screen if license is not active
    if (licenseStatus != LicenseStatus.active) {
      return MaterialApp(
        title: 'Amer Dokan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: ActivationScreen(
          onActivated: () {
            // Restart the app flow after activation
            runApp(AmerDokanApp(isLoggedIn: isLoggedIn, licenseStatus: LicenseStatus.active));
          },
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
      ],
      child: MaterialApp(
        title: 'Amer Dokan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: isLoggedIn ? '/home' : '/login',
        routes: {
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const MainScreen(),
        },
      ),
    );
  }
}
