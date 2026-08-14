import 'dart:io';
import 'package:excel/excel.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class BackupService {
  static final _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  static const _backupFileName = 'amer_dokan_backup.db';
  static const _lastBackupKey = 'last_backup_time';

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      print('GOOGLE_SIGN_IN_ERROR: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  static Future<GoogleSignInAccount?> get currentUser async {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  }

  static Future<drive.DriveApi?> _getDriveApi() async {
    final account = await currentUser;
    if (account == null) return null;
    final auth = await account.authentication;
    final client = GoogleAuthClient({'Authorization': 'Bearer ${auth.accessToken}'});
    return drive.DriveApi(client);
  }

  static Future<String> _getDbPath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, 'amer_dokan.db');
  }

  /// Get public Download directory on Android or app docs dir
  static Future<Directory> getPublicDownloadDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Export local SQLite database file (.db) to Download folder
  static Future<String> exportLocalDatabaseBackup() async {
    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('ডেটাবেস ফাইল পাওয়া যায়নি');
    }

    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final fileName = 'amerdokan_db_$dateStr.db';
    final dir = await getPublicDownloadDir();
    final targetPath = p.join(dir.path, fileName);

    await dbFile.copy(targetPath);
    return targetPath;
  }

  /// Export full structured Excel backup (.xlsx) to Download folder
  static Future<String> exportLocalExcelBackup() async {
    final excel = Excel.createExcel();

    // Sheet 1: Customers
    final custSheet = excel['Customers'];
    custSheet.appendRow([
      TextCellValue('id'),
      TextCellValue('name'),
      TextCellValue('phone'),
      TextCellValue('address'),
      TextCellValue('photo_path'),
      TextCellValue('credit_limit'),
      TextCellValue('created_at'),
    ]);
    final customers = await DatabaseHelper.instance.getAllCustomers();
    for (final c in customers) {
      custSheet.appendRow([
        IntCellValue(c.id ?? 0),
        TextCellValue(c.name),
        TextCellValue(c.phone),
        TextCellValue(c.address ?? ''),
        TextCellValue(c.photoPath ?? ''),
        DoubleCellValue(c.creditLimit),
        TextCellValue(c.createdAt.toIso8601String()),
      ]);
    }

    // Sheet 2: Transactions
    final txnSheet = excel['Transactions'];
    txnSheet.appendRow([
      TextCellValue('id'),
      TextCellValue('customer_id'),
      TextCellValue('amount'),
      TextCellValue('description'),
      TextCellValue('date'),
      TextCellValue('created_at'),
    ]);
    final db = await DatabaseHelper.instance.database;
    final txns = await db.query('transactions', orderBy: 'id ASC');
    for (final t in txns) {
      txnSheet.appendRow([
        IntCellValue((t['id'] as num).toInt()),
        IntCellValue((t['customer_id'] as num).toInt()),
        DoubleCellValue((t['amount'] as num).toDouble()),
        TextCellValue(t['description']?.toString() ?? ''),
        TextCellValue(t['date']?.toString() ?? ''),
        TextCellValue(t['created_at']?.toString() ?? ''),
      ]);
    }

    // Sheet 3: Payments
    final pmtSheet = excel['Payments'];
    pmtSheet.appendRow([
      TextCellValue('id'),
      TextCellValue('customer_id'),
      TextCellValue('amount'),
      TextCellValue('note'),
      TextCellValue('date'),
      TextCellValue('created_at'),
    ]);
    final pmts = await db.query('payments', orderBy: 'id ASC');
    for (final p in pmts) {
      pmtSheet.appendRow([
        IntCellValue((p['id'] as num).toInt()),
        IntCellValue((p['customer_id'] as num).toInt()),
        DoubleCellValue((p['amount'] as num).toDouble()),
        TextCellValue(p['note']?.toString() ?? ''),
        TextCellValue(p['date']?.toString() ?? ''),
        TextCellValue(p['created_at']?.toString() ?? ''),
      ]);
    }

    // Remove default Sheet1
    excel.delete('Sheet1');

    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final fileName = 'amerdokan_backup_data_$dateStr.xlsx';
    final dir = await getPublicDownloadDir();
    final targetPath = p.join(dir.path, fileName);

    final bytes = excel.encode();
    if (bytes != null) {
      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(bytes);
    }
    return targetPath;
  }

  /// Manual backup to Google Drive
  static Future<bool> backupToDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return false;

      final fileContent = await dbFile.readAsBytes();
      final media = drive.Media(Stream.value(fileContent), fileContent.length);

      final existing = await driveApi.files.list(
        q: "name='$_backupFileName' and trashed=false",
        spaces: 'drive',
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        await driveApi.files.update(
          drive.File(),
          existing.files!.first.id!,
          uploadMedia: media,
        );
      } else {
        await driveApi.files.create(
          drive.File()..name = _backupFileName,
          uploadMedia: media,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restore from Google Drive
  static Future<bool> restoreFromDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final existing = await driveApi.files.list(
        q: "name='$_backupFileName' and trashed=false",
        spaces: 'drive',
      );

      if (existing.files == null || existing.files!.isEmpty) return false;

      final fileId = existing.files!.first.id!;
      final media = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final dbPath = await _getDbPath();
      await File(dbPath).writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Auto backup — runs if last backup was more than 24 hours ago
  static Future<void> autoBackupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final autoEnabled = prefs.getBool('auto_backup') ?? false;
    if (!autoEnabled) return;

    final lastStr = prefs.getString(_lastBackupKey);
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null && DateTime.now().difference(last).inHours < 24) return;
    }

    await backupToDrive();
  }

  static Future<String?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackupKey);
  }

  static Future<void> setAutoBackup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', value);
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_backup') ?? false;
  }

  // ─── DEDICATED HIDDEN LOCAL BACKUP DIRECTORY & 3-DAY AUTO BACKUP ─────
  static const _last3DayBackupKey = 'last_local_3day_backup_time';

  /// Get or create dedicated hidden directory for app backups (.amerdokan_backups)
  static Future<Directory> getHiddenBackupDir() async {
    Directory targetDir;
    if (Platform.isAndroid) {
      targetDir = Directory('/storage/emulated/0/.amerdokan_backups');
      try {
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        final nomedia = File(p.join(targetDir.path, '.nomedia'));
        if (!await nomedia.exists()) {
          await nomedia.create();
        }
        return targetDir;
      } catch (_) {
        final docs = await getApplicationDocumentsDirectory();
        targetDir = Directory(p.join(docs.path, '.amerdokan_backups'));
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      targetDir = Directory(p.join(docs.path, '.amerdokan_backups'));
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Perform a local SQLite DB backup into the dedicated hidden directory
  static Future<String> performLocalDbBackupToHiddenDir() async {
    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('ডেটাবেস ফাইল পাওয়া যায়নি');
    }

    final hiddenDir = await getHiddenBackupDir();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final backupFileName = 'amerdokan_db_auto_$dateStr.db';
    final targetPath = p.join(hiddenDir.path, backupFileName);

    await dbFile.copy(targetPath);
    return targetPath;
  }

  /// Auto backup every 3 days (72 hours) - DB only to hidden app backup directory
  static Future<bool> autoLocalBackupEvery3Days() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastStr = prefs.getString(_last3DayBackupKey);

      if (lastStr != null) {
        final lastDate = DateTime.tryParse(lastStr);
        if (lastDate != null && DateTime.now().difference(lastDate).inHours < 72) {
          return false; // Less than 3 days, skip
        }
      }

      // Perform 3-day DB backup
      final backupPath = await performLocalDbBackupToHiddenDir();
      await prefs.setString(_last3DayBackupKey, DateTime.now().toIso8601String());

      // Clean up old auto backups (keep last 10)
      final hiddenDir = await getHiddenBackupDir();
      final files = hiddenDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith('amerdokan_db_auto_'))
          .toList();

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (files.length > 10) {
        for (int i = 10; i < files.length; i++) {
          try {
            await files[i].delete();
          } catch (_) {}
        }
      }

      print('AUTOMATIC_3DAY_BACKUP_CREATED: $backupPath');
      return true;
    } catch (e) {
      print('AUTOMATIC_3DAY_BACKUP_ERROR: $e');
      return false;
    }
  }

  /// List all backups stored in the hidden dedicated directory
  static Future<List<File>> getHiddenBackupFiles() async {
    final dir = await getHiddenBackupDir();
    if (!await dir.exists()) return [];

    final list = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db') || f.path.endsWith('.xlsx'))
        .toList();

    list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return list;
  }

  /// Restore database from a specific file in the hidden backup folder
  static Future<bool> restoreFromHiddenBackupFile(File backupFile) async {
    if (!await backupFile.exists()) return false;
    final dbPath = await _getDbPath();
    await backupFile.copy(dbPath);
    return true;
  }

  /// Restore database from any local .db file selected by user
  static Future<bool> restoreFromLocalDbFile(File dbFile) async {
    try {
      if (!await dbFile.exists()) return false;
      final dbPath = await _getDbPath();
      await dbFile.copy(dbPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getLast3DayBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_last3DayBackupKey);
  }
}
