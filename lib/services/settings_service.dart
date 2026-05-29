import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _shopNameKey = 'shop_name';

  static Future<String> getShopName() async {
    final prefs = await SharedPreferences.getInstance();
    final shopName = prefs.getString(_shopNameKey)?.trim();
    return shopName != null && shopName.isNotEmpty ? shopName : 'আমের দোকান';
  }
}
