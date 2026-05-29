import 'package:url_launcher/url_launcher.dart';
import 'message_templates.dart';

class SmsService {
  static Future<void> sendBakiReminder(String phone, double amount) async {
    final message = await MessageTemplates.dueReminder(amount);
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      throw 'Could not launch SMS';
    }
  }

  static Future<void> sendPaymentNotification(String phone, double paidAmount, double remainingDue) async {
    final message = await MessageTemplates.paymentNotification(paidAmount, remainingDue);
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      throw 'Could not launch SMS';
    }
  }
}
