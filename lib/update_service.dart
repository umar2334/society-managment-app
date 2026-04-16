// lib/update_service.dart
// ══════════════════════════════════════════════════════════════════
// KARIM NAGAR — AUTO UPDATE SYSTEM
//
// ADMIN KO SIRF YEH KARNA HAI JAB UPDATE DENA HO:
//   1. Firebase Console → Realtime Database → app_version node update karo:
//        version_code: 28  (har baar +1)
//        version: "1.0.28"
//        apk_url: GitHub Release APK ka direct download link
//        release_notes: "Kya naya hai"
//        force_update: false
//   2. Admin Dashboard → "Update Notification" button dabao
//      (pehli baar Server Key maanga jayega — Firebase Console se copy karo)
// ══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';

class UpdateService {
  static final _ref = FirebaseDatabase.instance.ref('app_version');

  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final packageInfo  = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 1;

      final snapshot = await _ref.get();
      if (!snapshot.exists) return null;

      final data        = Map<String, dynamic>.from(snapshot.value as Map);
      final latestBuild = (data['version_code'] as num?)?.toInt() ?? 1;

      if (latestBuild <= currentBuild) return null;

      final prefs     = await SharedPreferences.getInstance();
      final dismissed = prefs.getInt('dismissed_version') ?? 0;
      if (dismissed >= latestBuild) return null;

      return data;
    } catch (e) {
      debugPrint('UpdateService: $e');
      return null;
    }
  }

  static Future<void> dismissVersion(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dismissed_version', versionCode);
  }

  // ── APK Download + Install ─────────────────────────────────────
  static Future<void> downloadAndInstall(
    String apkUrl,
    void Function(double progress, String status) onProgress,
  ) async {
    try {
      onProgress(0.01, 'Connecting...');
      final request  = http.Request('GET', Uri.parse(apkUrl));
      final client   = http.Client();
      final response = await client.send(request);
      final total    = response.contentLength ?? 0;

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/society_update.apk');
      final sink = file.openWrite();

      int downloaded = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        final pct = total > 0 ? downloaded / total : 0.0;
        onProgress(pct, 'Downloading ${(pct * 100).toStringAsFixed(0)}%');
      }
      await sink.close();
      client.close();

      onProgress(1.0, 'Installing...');
      await OpenFilex.open(file.path);
    } catch (e) {
      onProgress(-1, 'Error: $e');
    }
  }

  // ── FCM Push Notification (Legacy HTTP API) ────────────────────
  // Server Key: Firebase Console → Project Settings → Cloud Messaging → Server Key
  static Future<bool> sendUpdatePushNotification({
    required String serverKey,
    required String version,
    required String releaseNotes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': '/topics/society_updates',
          'priority': 'high',
          'notification': {
            'title': '🆕 App Update Available — v$version',
            'body': releaseNotes.isNotEmpty
                ? releaseNotes
                : 'Naya update available hai. Tap karo update karne ke liye.',
            'sound': 'default',
            'android_channel_id': 'update_channel',
          },
          'data': {
            'type': 'app_update',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Server Key save/load ───────────────────────────────────────
  static Future<String> getSavedServerKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_server_key') ?? '';
  }

  static Future<void> saveServerKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_server_key', key);
  }
}

// ─────────────────────────────────────────────────────────────────
// UpdateChecker — login ke baad automatically chalega
// ─────────────────────────────────────────────────────────────────
class UpdateChecker extends StatefulWidget {
  final Widget child;
  const UpdateChecker({super.key, required this.child});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), _checkUpdate);
  }

  Future<void> _checkUpdate() async {
    final data = await UpdateService.checkForUpdate();
    if (data != null && mounted) showUpdateDialog(context, data);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────────
// showUpdateDialog — kahi se bhi call kar sakte hain
// ─────────────────────────────────────────────────────────────────
void showUpdateDialog(BuildContext context, Map<String, dynamic> data) {
  final bool   force   = data['force_update'] == true;
  final String version = data['version']?.toString()       ?? '';
  final String notes   = data['release_notes']?.toString() ?? 'Naye features aur bug fixes';
  final String apkUrl  = data['apk_url']?.toString()       ?? '';

  showDialog(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) => WillPopScope(
      onWillPop: () async => !force,
      child: _UpdateDialog(
        force: force,
        version: version,
        notes: notes,
        apkUrl: apkUrl,
        versionCode: (data['version_code'] as num?)?.toInt() ?? 0,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// _UpdateDialog — download progress ke saath
// ─────────────────────────────────────────────────────────────────
class _UpdateDialog extends StatefulWidget {
  final bool   force;
  final String version;
  final String notes;
  final String apkUrl;
  final int    versionCode;

  const _UpdateDialog({
    required this.force,
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.versionCode,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool   _downloading = false;
  double _progress    = 0;
  String _status      = '';
  bool   _error       = false;

  Future<void> _startDownload() async {
    if (widget.apkUrl.isEmpty) return;

    // Google Drive link → browser mein kholo (fast download)
    if (widget.apkUrl.contains('drive.google.com')) {
      await UpdateService.dismissVersion(widget.versionCode);
      final uri = Uri.parse(widget.apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // GitHub ya direct link → app mein download + install
    setState(() { _downloading = true; _error = false; });
    await UpdateService.downloadAndInstall(widget.apkUrl, (pct, status) {
      if (mounted) setState(() {
        _progress = pct;
        _status   = status;
        _error    = pct < 0;
      });
    });
    if (mounted && _progress >= 1.0) {
      await UpdateService.dismissVersion(widget.versionCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandDark, AppTheme.brandLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                color: AppTheme.brand.withOpacity(0.35),
                blurRadius: 18, offset: const Offset(0, 7),
              )],
            ),
            child: const Icon(Icons.system_update_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 18),

          Text('New Update Available! 🎉',
              style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),

          if (widget.version.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.brand.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Version ${widget.version}',
                  style: GoogleFonts.sora(
                      fontSize: 12, color: AppTheme.brand,
                      fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 16),

          // Release Notes
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.new_releases_rounded, color: AppTheme.gold, size: 16),
                const SizedBox(width: 6),
                Text("What's New:", style: GoogleFonts.sora(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted)),
              ]),
              const SizedBox(height: 8),
              Text(widget.notes, style: GoogleFonts.sora(
                  fontSize: 13, color: AppTheme.textPrimary, height: 1.6)),
            ]),
          ),
          const SizedBox(height: 20),

          // Download Progress
          if (_downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
                backgroundColor: AppTheme.brand.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                    _error ? Colors.red : AppTheme.brand),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ? '❌ $_status' : _status,
              style: GoogleFonts.sora(
                  fontSize: 12,
                  color: _error ? Colors.red : AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
          ],

          // Update Button
          if (!_downloading || _error)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(_error ? 'Retry' : 'Update Now',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: AppTheme.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),

          // Skip
          if (!widget.force && !_downloading) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Later', style: GoogleFonts.sora(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
