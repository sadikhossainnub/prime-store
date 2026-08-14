import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline License System using HMAC-SHA256
/// Key format: XXXX-XXXX-XXXX-XXXX (16 hex chars split into 4 groups)
/// The key encodes: expiry date + device ID, signed with a secret
class LicenseService {
  // ⚠️ SECRET KEY — keep this private, never share!
  static const String _secret = 'AmErDoKaN@2026#PrImE\$sToRe!KeY';

  static const String _prefActivated = 'license_activated';
  static const String _prefExpiry = 'license_expiry';
  static const String _prefDeviceId = 'license_device_id';
  static const String _prefCustomer = 'license_customer';

  /// Check if device has a valid, non-expired license
  static Future<LicenseStatus> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final activated = prefs.getBool(_prefActivated) ?? false;
    if (!activated) return LicenseStatus.notActivated;

    final expiryStr = prefs.getString(_prefExpiry);
    if (expiryStr == null) return LicenseStatus.notActivated;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return LicenseStatus.notActivated;

    final now = DateTime.now();
    if (now.isAfter(expiry)) return LicenseStatus.expired;

    final daysLeft = expiry.difference(now).inDays;
    return LicenseStatus.active;
  }

  /// Returns days remaining, or 0 if expired/not activated
  static Future<int> getDaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_prefExpiry);
    if (expiryStr == null) return 0;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return 0;
    final days = expiry.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  static Future<DateTime?> getExpiryDate() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_prefExpiry);
    if (expiryStr == null) return null;
    return DateTime.tryParse(expiryStr);
  }

  static Future<String> getCustomerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefCustomer) ?? '';
  }

  /// Get or create a stable device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_prefDeviceId);
    if (id == null) {
      final rand = Random.secure();
      final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
      id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
      await prefs.setString(_prefDeviceId, id);
    }
    return id;
  }

  /// Activate app with a license key
  /// Returns [ActivationResult]
  static Future<ActivationResult> activate(String rawKey) async {
    final key = rawKey.trim().toUpperCase().replaceAll('-', '');
    if (key.length != 16) {
      return ActivationResult(success: false, message: 'Key format ভুল। সঠিক key দিন।');
    }

    try {
      // Key structure: [4 chars device prefix][4 chars expiry encoded][4 chars customer hash][4 chars HMAC]
      final devicePart = key.substring(0, 4);
      final expiryPart = key.substring(4, 8);
      final customerPart = key.substring(8, 12);
      final hmacPart = key.substring(12, 16);

      // Verify HMAC signature
      final payload = '$devicePart$expiryPart$customerPart';
      final expectedHmac = _computeHmac(payload).substring(0, 4);
      if (hmacPart != expectedHmac) {
        return ActivationResult(success: false, message: 'Key টি সঠিক নয়। যোগাযোগ করুন।');
      }

      // Decode device ID prefix
      final deviceId = await getDeviceId();
      final devicePrefix = _devicePrefix(deviceId);
      if (devicePart != devicePrefix) {
        return ActivationResult(
          success: false,
          message: 'এই key অন্য device-এর জন্য। আপনার Device ID দিয়ে নতুন key নিন।',
        );
      }

      // Decode expiry date
      final expiryDate = _decodeExpiry(expiryPart);
      if (expiryDate == null) {
        return ActivationResult(success: false, message: 'Key-এ তারিখ decode করা যায়নি।');
      }
      if (DateTime.now().isAfter(expiryDate)) {
        return ActivationResult(success: false, message: 'এই key মেয়াদ শেষ হয়ে গেছে।');
      }

      // Save activation
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefActivated, true);
      await prefs.setString(_prefExpiry, expiryDate.toIso8601String());

      final daysLeft = expiryDate.difference(DateTime.now()).inDays;
      return ActivationResult(
        success: true,
        message: 'সফলভাবে সক্রিয় হয়েছে! মেয়াদ: $daysLeft দিন।',
        expiryDate: expiryDate,
      );
    } catch (e) {
      return ActivationResult(success: false, message: 'Key যাচাই করতে সমস্যা হয়েছে।');
    }
  }

  static Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefActivated);
    await prefs.remove(_prefExpiry);
    await prefs.remove(_prefCustomer);
  }

  // ─── Internal Helpers ────────────────────────────────────────────────────

  static String _computeHmac(String payload) {
    final key = utf8.encode(_secret);
    final data = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return digest.toString().toUpperCase();
  }

  /// First 4 hex chars of HMAC of device ID
  static String _devicePrefix(String deviceId) {
    return _computeHmac(deviceId).substring(0, 4);
  }

  /// Encode expiry: days since epoch as 4 hex chars
  static String encodeExpiry(DateTime expiry) {
    final epochDays = expiry.difference(DateTime(2024, 1, 1)).inDays;
    return epochDays.toRadixString(16).padLeft(4, '0').toUpperCase();
  }

  /// Decode expiry from 4 hex chars
  static DateTime? _decodeExpiry(String hex) {
    try {
      final days = int.parse(hex, radix: 16);
      return DateTime(2024, 1, 1).add(Duration(days: days));
    } catch (_) {
      return null;
    }
  }

  /// Customer hash: first 4 chars of HMAC of customer name
  static String customerHash(String customerName) {
    return _computeHmac(customerName.trim().toUpperCase()).substring(0, 4);
  }

  /// Generate a key for given device ID, expiry date, customer name
  /// This is used by the KEY GENERATOR TOOL (not in app)
  static String generateKey({
    required String deviceId,
    required DateTime expiryDate,
    required String customerName,
  }) {
    final devicePrefix = _devicePrefix(deviceId);
    final expiryEncoded = encodeExpiry(expiryDate);
    final custHash = customerHash(customerName);
    final payload = '$devicePrefix$expiryEncoded$custHash';
    final hmac = _computeHmac(payload).substring(0, 4);
    final raw = '$devicePrefix$expiryEncoded$custHash$hmac';
    // Format as XXXX-XXXX-XXXX-XXXX
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}';
  }
}

enum LicenseStatus { active, expired, notActivated }

class ActivationResult {
  final bool success;
  final String message;
  final DateTime? expiryDate;

  ActivationResult({required this.success, required this.message, this.expiryDate});
}
