import 'package:intl/intl.dart';
import 'settings_service.dart';

class MessageTemplates {
  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  static Future<String> dueReminder(double remainingDue) async {
    final shopName = await SettingsService.getShopName();
    final amountText = _currencyFormat.format(remainingDue);
    return '$shopName থেকে জানাচ্ছি, আপনার বাকি পাওনা $amountText টাকা। অনুগ্রহ করে দ্রুত পরিশোধ করুন।';
  }

  static Future<String> paymentNotification(double paidAmount, double remainingDue) async {
    final shopName = await SettingsService.getShopName();
    final paidText = _currencyFormat.format(paidAmount);
    if (remainingDue <= 0) {
      return '$shopName থেকে ধন্যবাদ! আপনার বাকি সম্পূর্ণ পরিশোধ হয়েছে। আপনার সহযোগিতার জন্য ধন্যবাদ।';
    }
    final remainingText = _currencyFormat.format(remainingDue);
    return '$shopName থেকে জানাচ্ছি, আপনার আজকের আদায় হয়েছে $paidText টাকা। আপনার বাকি এখন $remainingText টাকা। অনুগ্রহ করে পরবর্তী পরিশোধের ব্যবস্থা করুন।';
  }
}
