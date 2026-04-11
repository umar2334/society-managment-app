// lib/screens/login_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'update_service.dart';
import 'society_data.dart';
import 'admin_dashboard.dart';
import 'resident_dashboard.dart';

// ════════════════════════════════════════════════════════════════════════════
// EMAILJS CONFIG
// ════════════════════════════════════════════════════════════════════════════
class EmailJsConfig {
  static const String serviceId  = 'service_5hs73b7';
  static const String templateId = 'template_he93b31';
  static const String publicKey  = 'HKKD7CUwYJ9moOYPy';
}

class EmailService {
  static Future<bool> sendOtp({
    required String toEmail,
    required String houseId,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id':  EmailJsConfig.serviceId,
          'template_id': EmailJsConfig.templateId,
          'user_id':     EmailJsConfig.publicKey,
          'template_params': {
            'to_email':  toEmail,
            'house_id':  houseId,
            'otp_code':  otp,
            'app_name':  'Karim Nagar Society Portal',
          },
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('EmailJS error: $e');
      return false;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SAVED LOGIN HELPER
// ════════════════════════════════════════════════════════════════════════════
class SavedLoginService {
  static const _keyId   = 'saved_login_id';
  static const _keyPass = 'saved_login_pass';
  static const _keySave = 'saved_login_remember';

  static Future<void> save(String id, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId,   id);
    await prefs.setString(_keyPass, pass);
    await prefs.setBool(_keySave,   true);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyPass);
    await prefs.setBool(_keySave, false);
  }

  static Future<Map<String, String>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_keySave) ?? false;
    if (!remember) return null;
    final id   = prefs.getString(_keyId)   ?? '';
    final pass = prefs.getString(_keyPass) ?? '';
    if (id.isEmpty || pass.isEmpty) return null;
    return {'id': id, 'pass': pass};
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ════════════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure      = true;
  String _error      = '';
  bool _loading      = false;
  bool _rememberMe   = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  // Sirf fields fill karo — auto login nahi
  Future<void> _loadSavedLogin() async {
    final saved = await SavedLoginService.load();
    if (saved != null && mounted) {
      setState(() {
        _idCtrl.text   = saved['id']!;
        _passCtrl.text = saved['pass']!;
        _rememberMe    = true;
      });
    }
  }

  void _handleLogin() async {
    setState(() { _error = ''; _loading = true; });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() { _loading = false; });

    final id   = _idCtrl.text.trim().toUpperCase();
    final pass = _passCtrl.text.trim();

    if (id.isEmpty || pass.isEmpty) {
      setState(() => _error = 'ID aur Password daalen!');
      return;
    }

    // Remember Me — save karo
    if (_rememberMe) {
      await SavedLoginService.save(id, pass);
    } else {
      await SavedLoginService.clear();
    }

    // Admin check
    if (SocietyData.isAdminLogin(id, pass)) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => AdminDashboard(adminId: id)));
    } else {
      final valid = SocietyData.userRecords
          .any((r) => r['house'] == id && r['pass'] == pass);
      if (valid) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => ResidentDashboard(houseId: id)));
      } else {
        await SavedLoginService.clear(); // wrong pass — clear karo
        setState(() {
          _error      = 'Invalid House ID or Password!';
          _rememberMe = false;
        });
      }
    }
  }

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ForgotPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UpdateChecker(
      child: Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Hero ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF003D99), Color(0xFF0052CC), Color(0xFF2684FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Stack(children: [
              // Decorative circles
              Positioned(right: -30, top: -30,
                child: Container(width: 180, height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.07), width: 40)))),
              Positioned(left: -20, bottom: -20,
                child: Container(width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 30)))),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 56),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // App icon
                    Container(
                      width: 68, height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 22),
                    Text('Welcome Back',
                        style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 30,
                            fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white70, size: 12),
                          const SizedBox(width: 5),
                          Text('Karim Nagar Society Portal',
                              style: GoogleFonts.sora(
                                  color: Colors.white.withOpacity(0.9), fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Card ──
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0052CC).withOpacity(0.10),
                      blurRadius: 40, offset: const Offset(0, 12)),
                  BoxShadow(color: Colors.black.withOpacity(0.04),
                      blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sign In', style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('Enter your House ID or Admin credentials',
                    style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 24),
                _lbl('House ID or Admin'),
                TextField(
                  controller: _idCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: "e.g. 38A or NOVROZ",
                    prefixIcon: Icon(Icons.home_work_rounded,
                        color: AppTheme.brand, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                _lbl('Password'),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  onSubmitted: (_) => _handleLogin(),
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.vpn_key_rounded,
                        color: AppTheme.brand, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textMuted, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Remember Me ──
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _rememberMe
                          ? AppTheme.brand.withOpacity(0.07)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _rememberMe
                            ? AppTheme.brand.withOpacity(0.3)
                            : AppTheme.divider,
                      ),
                    ),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: _rememberMe
                              ? AppTheme.brand : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _rememberMe
                                ? AppTheme.brand : AppTheme.textMuted,
                            width: 2,
                          ),
                        ),
                        child: _rememberMe
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text('Remember ID & Password',
                          style: GoogleFonts.sora(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _rememberMe
                                  ? AppTheme.brand
                                  : AppTheme.textSecondary)),
                      const Spacer(),
                      Icon(Icons.bookmark_rounded,
                          size: 16,
                          color: _rememberMe
                              ? AppTheme.brand
                              : AppTheme.textMuted),
                    ]),
                  ),
                ),

                // ── Forgot Password ──
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _showForgotPassword,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                      child: Text('Forgot Password?',
                          style: GoogleFonts.sora(
                              fontSize: 12, color: AppTheme.brand,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.brand)),
                    ),
                  ),
                ),

                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.danger.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error,
                            style: GoogleFonts.sora(
                                color: AppTheme.danger, fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Text('SIGN IN',
                                style: GoogleFonts.sora(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5, fontSize: 14)),
                          ]),
                  ),
                ),
              ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 40, height: 1, color: AppTheme.divider),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('KARIM NAGAR COLONY',
                      style: GoogleFonts.sora(fontSize: 9, color: AppTheme.textMuted,
                          letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                ),
                Container(width: 40, height: 1, color: AppTheme.divider),
              ]),
              const SizedBox(height: 10),
              Text('39A Metroville SITE Area · Karachi',
                  style: GoogleFonts.sora(fontSize: 10, color: AppTheme.textMuted),
                  textAlign: TextAlign.center),
            ]),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(),
        style: GoogleFonts.sora(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary, letterSpacing: 1)),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD — 3 steps with real EmailJS OTP
// ════════════════════════════════════════════════════════════════════════════
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  int _step = 0;
  final _houseCtrl   = TextEditingController();
  final _otpCtrl     = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _err = '', _maskedEmail = '', _generatedOtp = '';
  bool _obscNew = true, _obscConf = true, _sending = false;
  Map<String, dynamic>? _found;

  Future<void> _step1() async {
    final houseId = _houseCtrl.text.trim().toUpperCase();
    if (houseId.isEmpty) { setState(() => _err = 'Enter House ID'); return; }
    if (SocietyData.isAdminLogin(houseId, '')) {
      setState(() => _err = 'Contact the chairman to change the admin password.');
      return;
    }
    final record = SocietyData.userRecords.firstWhere(
      (r) => r['house'] == houseId, orElse: () => {});
    if (record.isEmpty) { setState(() => _err = 'House ID not found!'); return; }

    final email = record['email'] ?? 'Not Registered';
    if (email == 'Not Registered' || email.isEmpty) {
      setState(() => _err = 'No email is registered for this house.\nPlease contact the admin.');
      return;
    }

    final otp = (100000 + Random().nextInt(900000)).toString();
    _generatedOtp = otp;
    _found = record;

    final parts = email.split('@');
    _maskedEmail = parts.length == 2
        ? '${parts[0].length > 3 ? parts[0].substring(0, 3) : parts[0][0]}***@${parts[1]}'
        : email;

    setState(() { _sending = true; _err = ''; });
    final sent = await EmailService.sendOtp(
        toEmail: email, houseId: houseId, otp: otp);
    if (!mounted) return;
    setState(() => _sending = false);

    if (sent) {
      setState(() => _step = 1);
    } else {
      setState(() => _err = 'Email not sent. Please check your internet connection.');
    }
  }

  void _step2() {
    if (_otpCtrl.text.trim() == _generatedOtp) {
      setState(() { _err = ''; _step = 2; });
    } else {
      setState(() => _err = 'Invalid code! Please check your email.');
    }
  }

  void _step3() async {
    final np = _newPassCtrl.text.trim();
    final cp = _confirmCtrl.text.trim();
    if (np.isEmpty) { setState(() => _err = 'Enter New Password'); return; }
    if (np.length < 4) { setState(() => _err = 'Minimum 4 characters'); return; }
    if (np != cp) { setState(() => _err = 'Passwords do not match!'); return; }

    final idx = SocietyData.userRecords.indexOf(_found!);
    if (idx != -1) {
      SocietyData.userRecords[idx]['pass'] = np;
      await SocietyData.saveUsers();
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text('Password updated! House ${_found?['house']}',
            style: GoogleFonts.sora(
                fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _resend() async {
    final otp = (100000 + Random().nextInt(900000)).toString();
    _generatedOtp = otp;
    setState(() => _sending = true);
    await EmailService.sendOtp(
        toEmail: _found?['email'] ?? '',
        houseId: _found?['house'] ?? '',
        otp: otp);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('New code sent to: $_maskedEmail',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.brand,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 44, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          _StepIndicator(current: _step),
          const SizedBox(height: 24),
          if (_step == 0) _buildStep1(),
          if (_step == 1) _buildStep2(),
          if (_step == 2) _buildStep3(),
        ]),
      ),
    );
  }

  Widget _buildStep1() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _title('Forgot Password', 'Enter House ID — OTP will be sent to your registered email.'),
    const SizedBox(height: 20),
    TextField(
      controller: _houseCtrl,
      textCapitalization: TextCapitalization.characters,
      style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary),
      decoration: const InputDecoration(
          labelText: 'House ID', hintText: 'e.g. 38A',
          prefixIcon: Icon(Icons.home_work_rounded, color: AppTheme.brand)),
    ),
    Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppTheme.brand.withOpacity(0.15))),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: AppTheme.brand, size: 17),
        const SizedBox(width: 9),
        Expanded(child: Text(
            'OTP will be sent to your registered email.\nIf no email registered, contact admin.',
            style: GoogleFonts.sora(fontSize: 11, color: AppTheme.brand,
                fontWeight: FontWeight.w500))),
      ]),
    ),
    if (_err.isNotEmpty) _errBox(_err),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: _sending ? null : _step1,
        icon: _sending
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.email_rounded, size: 18),
        label: Text(_sending ? 'Sending...' : 'SEND OTP TO EMAIL',
            style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 13)),
        style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    ),
  ]);

  Widget _buildStep2() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _title('Enter OTP', 'Check your email'),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.success.withOpacity(0.25))),
      child: Row(children: [
        const Icon(Icons.mark_email_read_rounded, color: AppTheme.success, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Email Sent!', style: GoogleFonts.sora(
              color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 13)),
          Text('Code sent to: $_maskedEmail', style: GoogleFonts.sora(
              color: AppTheme.textSecondary, fontSize: 11)),
          Text('Check Spam folder too', style: GoogleFonts.sora(
              color: AppTheme.textMuted, fontSize: 10)),
        ])),
      ]),
    ),
    const SizedBox(height: 18),
    TextField(
      controller: _otpCtrl,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary, letterSpacing: 10),
      decoration: InputDecoration(
        labelText: 'Verification Code',
        hintText: '• • • • • •',
        hintStyle: GoogleFonts.sora(
            letterSpacing: 8, color: AppTheme.textMuted, fontSize: 22),
        counterText: '',
        prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.brand),
      ),
    ),
    if (_err.isNotEmpty) _errBox(_err),
    const SizedBox(height: 16),
    SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: _step2,
        icon: const Icon(Icons.verified_rounded, size: 18),
        label: Text('VERIFY CODE',
            style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 13)),
        style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    ),
    const SizedBox(height: 14),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Didn't get the code? ",
          style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textMuted)),
      GestureDetector(
        onTap: _sending ? null : _resend,
        child: Text(_sending ? 'Sending...' : 'Resend',
            style: GoogleFonts.sora(fontSize: 12, color: AppTheme.brand,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.brand)),
      ),
    ]),
  ]);

  Widget _buildStep3() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _title('Set New Password', 'House ${_found?['house']} · Create a strong password'),
    const SizedBox(height: 20),
    TextField(
      controller: _newPassCtrl,
      obscureText: _obscNew,
      style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: 'New Password',
        prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.brand),
        suffixIcon: IconButton(
          icon: Icon(_obscNew ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.textMuted, size: 20),
          onPressed: () => setState(() => _obscNew = !_obscNew),
        ),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _confirmCtrl,
      obscureText: _obscConf,
      style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: 'Confirm New Password',
        prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppTheme.brand),
        suffixIcon: IconButton(
          icon: Icon(_obscConf ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.textMuted, size: 20),
          onPressed: () => setState(() => _obscConf = !_obscConf),
        ),
      ),
    ),
    if (_err.isNotEmpty) _errBox(_err),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: _step3,
        icon: const Icon(Icons.check_circle_rounded, size: 18),
        label: Text('UPDATE PASSWORD',
            style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 13)),
        style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    ),
  ]);

  Widget _title(String t, String s) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: GoogleFonts.sora(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(s, style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
      ]);

  Widget _errBox(String msg) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withOpacity(0.2))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppTheme.danger, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
          style: GoogleFonts.sora(
              color: AppTheme.danger, fontSize: 11,
              fontWeight: FontWeight.w600))),
    ]),
  );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    final labels = ['House ID', 'Verify OTP', 'New Pass'];
    return Row(
      children: List.generate(3, (i) {
        final done = i < current, active = i == current;
        return Expanded(child: Row(children: [
          Expanded(child: Column(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppTheme.success
                    : active ? AppTheme.brand : AppTheme.surface,
                border: Border.all(
                    color: done
                        ? AppTheme.success
                        : active ? AppTheme.brand : AppTheme.divider,
                    width: 2),
              ),
              child: Center(child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${i + 1}', style: GoogleFonts.sora(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: active ? Colors.white : AppTheme.textMuted))),
            ),
            const SizedBox(height: 4),
            Text(labels[i], style: GoogleFonts.sora(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: active || done
                    ? AppTheme.textPrimary : AppTheme.textMuted),
                textAlign: TextAlign.center),
          ])),
          if (i < 2) Expanded(child: Container(
              height: 2, margin: const EdgeInsets.only(bottom: 18),
              color: i < current ? AppTheme.success : AppTheme.divider)),
        ]));
      }),
    );
  }
}
