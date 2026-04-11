// lib/update_service.dart
// ══════════════════════════════════════════════════════════════════
// KARIM NAGAR — AUTO UPDATE SYSTEM
// Firebase Realtime Database se version check hoga
//
// ADMIN KO SIRF YEH KARNA HAI JAB UPDATE DENA HO:
//   Firebase Console → Realtime Database → app_version node update karo
//   version_code: 1 → 2 (har baar +1 karo)
//   apk_url: naya Google Drive link daalo
// ══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
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

      // Check if user already dismissed this version
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getInt('dismissed_version') ?? 0;
      if (dismissed >= latestBuild) return null;

      return data;
    } catch (e) {
      debugPrint('UpdateService: $e');
      return null;
    }
  }

  // Save dismissed version
  static Future<void> dismissVersion(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dismissed_version', versionCode);
  }
}

// ─────────────────────────────────────────────────────────────────
// UpdateChecker — SplashScreen ke baad automatically chalega
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
    // 4 second delay — splash (3s) + login screen load hone do
    Future.delayed(const Duration(seconds: 4), _checkUpdate);
  }

  Future<void> _checkUpdate() async {
    final data = await UpdateService.checkForUpdate();
    if (data != null && mounted) _showUpdateDialog(data);
  }

  void _showUpdateDialog(Map<String, dynamic> data) {
    final bool   force   = data['force_update'] == true;
    final String version = data['version']?.toString()      ?? '';
    final String notes   = data['release_notes']?.toString() ?? 'Naye features aur bug fixes';
    final String apkUrl  = data['apk_url']?.toString()      ?? '';

    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => !force,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Update Icon ──
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

              // ── Title ──
              Text('New Update Available! 🎉',
                  style: GoogleFonts.sora(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),

              if (version.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Version $version',
                      style: GoogleFonts.sora(
                          fontSize: 12, color: AppTheme.brand,
                          fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 16),

              // ── Release Notes ──
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
                    const Icon(Icons.new_releases_rounded,
                        color: AppTheme.gold, size: 16),
                    const SizedBox(width: 6),
                    Text("What's New:",
                        style: GoogleFonts.sora(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted)),
                  ]),
                  const SizedBox(height: 8),
                  Text(notes,
                      style: GoogleFonts.sora(
                          fontSize: 13, color: AppTheme.textPrimary,
                          height: 1.6)),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Update Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (apkUrl.isEmpty) return;
                    // Dismiss save karo — update kar liya, dobara mat dikhao
                    final latestBuild = (data['version_code'] as num?)?.toInt() ?? 0;
                    await UpdateService.dismissVersion(latestBuild);
                    final uri = Uri.parse(apkUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: Text('Update Now',
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

              // ── Skip (only if not force) ──
              if (!force) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Later',
                        style: GoogleFonts.sora(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
