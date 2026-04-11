// lib/screens/privacy_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'society_data.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String _query = '';

  List<Map<String, dynamic>> get _filtered => SocietyData.userRecords
      .where((r) => r['house']!.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  void _showEditDialog(int globalIndex) {
    final record = SocietyData.userRecords[globalIndex];
    final mCtrl  = TextEditingController(
        text: record['mobile'] == 'Not Registered' ? '' : record['mobile']);
    final eCtrl  = TextEditingController(
        text: record['email']  == 'Not Registered' ? '' : record['email']);
    final pCtrl  = TextEditingController(text: record['pass']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Manage House ${record['house']}',
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              Text('Update resident contact & password',
                  style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 20),

              TextField(
                controller: mCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone_rounded, color: AppTheme.brand),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: eCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address (Forgot Password)',
                  hintText: 'resident@gmail.com',
                  prefixIcon: const Icon(Icons.email_rounded, color: AppTheme.brand),
                  helperText: (record['email'] == 'Not Registered' ||
                          (record['email'] ?? '').isEmpty)
                      ? '⚠️ Email required for password reset'
                      : '✓ Email is set',
                  helperStyle: GoogleFonts.sora(
                      color: (record['email'] == 'Not Registered' ||
                              (record['email'] ?? '').isEmpty)
                          ? AppTheme.gold
                          : AppTheme.success,
                      fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: pCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reset Password',
                  prefixIcon: Icon(Icons.lock_reset_rounded, color: AppTheme.brand),
                ),
              ),
              const SizedBox(height: 24),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('CANCEL',
                        style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newMobile = mCtrl.text.trim().isEmpty
                          ? 'Not Registered' : mCtrl.text.trim();
                      final newEmail  = eCtrl.text.trim().isEmpty
                          ? 'Not Registered' : eCtrl.text.trim().toLowerCase();
                      final newPass   = pCtrl.text.trim().isEmpty
                          ? '1234' : pCtrl.text.trim();

                      // Memory update
                      SocietyData.userRecords[globalIndex]['mobile'] = newMobile;
                      SocietyData.userRecords[globalIndex]['email']  = newEmail;
                      SocietyData.userRecords[globalIndex]['pass']   = newPass;

                      // Firebase save — sirf is ek house ka
                      await SocietyData.saveUser(record['house']!);

                      if (!mounted) return;
                      setState(() {});
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('House ${record['house']} saved successfully!',
                              style: GoogleFonts.sora(
                                  fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('SAVE',
                        style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppTheme.brandDark,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Container(
          color: AppTheme.brandDark,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.sora(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search house number...',
              hintStyle: GoogleFonts.sora(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Colors.white54, size: 20),
              fillColor: Colors.white.withOpacity(0.13),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Colors.white30)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Text('${filtered.length} users',
                style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(width: 8),
            Container(width: 6, height: 6, decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.success)),
            const SizedBox(width: 4),
            Text('Mobile  ', style: GoogleFonts.sora(fontSize: 10, color: AppTheme.textMuted)),
            Container(width: 6, height: 6, decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.brand)),
            const SizedBox(width: 4),
            Text('Email', style: GoogleFonts.sora(fontSize: 10, color: AppTheme.textMuted)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final record      = filtered[i];
              final isReg       = record['mobile'] != 'Not Registered';
              final hasEmail    = record['email'] != null &&
                  record['email'] != 'Not Registered' &&
                  record['email']!.isNotEmpty;
              final globalIndex = SocietyData.userRecords.indexOf(record);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: [BoxShadow(color: AppTheme.brand.withOpacity(0.05),
                      blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTheme.brand, AppTheme.brandLight]),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(child: Text(
                        record['house']!.substring(record['house']!.length - 1),
                        style: GoogleFonts.sora(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 16))),
                  ),
                  title: Text('House # ${record['house']}',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700,
                          fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.phone_rounded, size: 11,
                          color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(record['mobile']!,
                          style: GoogleFonts.sora(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.email_rounded, size: 11,
                          color: hasEmail ? AppTheme.brand : AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Expanded(child: Text(
                          hasEmail ? record['email']! : 'Email not registered',
                          style: GoogleFonts.sora(fontSize: 10,
                              color: hasEmail ? AppTheme.brand : AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: isReg ? AppTheme.success : AppTheme.divider)),
                      const SizedBox(height: 4),
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: hasEmail ? AppTheme.brand : AppTheme.divider)),
                    ]),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showEditDialog(globalIndex),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.brand.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppTheme.brand, size: 18),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
