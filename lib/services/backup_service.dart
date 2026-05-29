import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

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
    } catch (_) {
      return null;
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

      // Check if backup already exists
      final existing = await driveApi.files.list(
        q: "name='$_backupFileName' and trashed=false",
        spaces: 'drive',
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        // Update existing
        await driveApi.files.update(
          drive.File(),
          existing.files!.first.id!,
          uploadMedia: media,
        );
      } else {
        // Create new
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
}
