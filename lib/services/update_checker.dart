import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static const _githubLatestReleaseUrl = 'https://api.github.com/repos/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/releases/latest';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_githubLatestReleaseUrl));
      if (response.statusCode != 200) return;

      final jsonBody = json.decode(response.body) as Map<String, dynamic>;
      final latestTag = jsonBody['tag_name'] as String?;
      final releaseUrl = jsonBody['html_url'] as String?;
      if (latestTag == null || releaseUrl == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      if (!_isNewerVersion(latestTag, currentVersion)) return;

      _showUpdateDialog(context, releaseUrl, latestTag, currentVersion);
    } catch (_) {
      // Fail silently - no internet or API issue should not crash the app.
    }
  }

  static bool _isNewerVersion(String latestTag, String currentVersion) {
    final latest = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;
    final current = currentVersion.startsWith('v') ? currentVersion.substring(1) : currentVersion;

    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();

    for (var index = 0; index < 3; index++) {
      final latestValue = (index < latestParts.length ? latestParts[index] : 0) ?? 0;
      final currentValue = (index < currentParts.length ? currentParts[index] : 0) ?? 0;
      if (latestValue > currentValue) return true;
      if (latestValue < currentValue) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String releaseUrl, String latestTag, String currentVersion) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Text('A new version ($latestTag) is available. You are running $currentVersion.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(releaseUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
