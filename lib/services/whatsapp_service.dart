import 'package:url_launcher/url_launcher.dart';
import 'message_templates.dart';

class WhatsappService {
  static Future<void> sendBakiReminder(String phone, double amount) async {
    final message = await MessageTemplates.dueReminder(amount);
    await _sendWhatsappMessage(phone, message);
  }

  static Future<void> sendPaymentNotification(String phone, double paidAmount, double remainingDue) async {
    final message = await MessageTemplates.paymentNotification(paidAmount, remainingDue);
    await _sendWhatsappMessage(phone, message);
  }

  static Future<void> _sendWhatsappMessage(String phone, String message) async {
    String sanitizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!sanitizedPhone.startsWith('88')) {
      sanitizedPhone = '88$sanitizedPhone';
    }

    final Uri whatsappUri = Uri.parse("https://wa.me/$sanitizedPhone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }
}
