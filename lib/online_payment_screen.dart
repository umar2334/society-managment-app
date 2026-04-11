// lib/online_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class OnlinePaymentScreen extends StatefulWidget {
  final bool isAdmin;
  const OnlinePaymentScreen({super.key, this.isAdmin = false});

  @override
  State<OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends State<OnlinePaymentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Static cache — sirf pehli baar SharedPreferences se load hoga
  static String _cachedNumber      = '0311-1234567';
  static String _cachedEngInstr    = 'After making an online payment, please send the payment screenshot to the above EasyPaisa number. Without sending the screenshot, your maintenance voucher will NOT be issued.';
  static String _cachedEngNote     = 'Thank you for your cooperation.';
  static String _cachedUrduInstr   = 'آن لائن پیمنٹ کرنے کے بعد پیمنٹ کی اسکرین شاٹ اس نمبر پر بھیج دیں';
  static String _cachedUrduWarning = 'ورنہ مینٹیننس کا وچر نہیں ملے گا — شکریہ';
  static bool   _cacheLoaded       = false;

  String _number       = _cachedNumber;
  String _engInstr     = _cachedEngInstr;
  String _engNote      = _cachedEngNote;
  String _urduInstr    = _cachedUrduInstr;
  String _urduWarning  = _cachedUrduWarning;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(_ctrl);
    _ctrl.forward();
    // Only load from SharedPreferences if not cached yet
    if (!_cacheLoaded) _loadSaved();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // ── Load / Save ──────────────────────────────────────────
  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _number      = p.getString('ep_number')       ?? _number;
      _engInstr    = p.getString('ep_eng_instr')    ?? _engInstr;
      _engNote     = p.getString('ep_eng_note')     ?? _engNote;
      _urduInstr   = p.getString('ep_urdu_instr')   ?? _urduInstr;
      _urduWarning = p.getString('ep_urdu_warning') ?? _urduWarning;
      // Update cache
      _cachedNumber      = _number;
      _cachedEngInstr    = _engInstr;
      _cachedEngNote     = _engNote;
      _cachedUrduInstr   = _urduInstr;
      _cachedUrduWarning = _urduWarning;
      _cacheLoaded       = true;
    });
  }

  Future<void> _saveAll() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('ep_number',       _number);
    await p.setString('ep_eng_instr',    _engInstr);
    await p.setString('ep_eng_note',     _engNote);
    await p.setString('ep_urdu_instr',   _urduInstr);
    await p.setString('ep_urdu_warning', _urduWarning);
  }

  // ── Edit Bottom Sheet ────────────────────────────────────
  void _openEditSheet() {
    final numCtrl   = TextEditingController(text: _number);
    final eng1Ctrl  = TextEditingController(text: _engInstr);
    final eng2Ctrl  = TextEditingController(text: _engNote);
    final urdu1Ctrl = TextEditingController(text: _urduInstr);
    final urdu2Ctrl = TextEditingController(text: _urduWarning);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Color(0xFFF4F5F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.edit_rounded, color: AppTheme.brand, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit Payment Info',
                        style: GoogleFonts.sora(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Fields
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editField('📱 EasyPaisa Number', numCtrl,
                          hint: '0311-1234567', keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),
                      _editField('ℹ️ English Instruction', eng1Ctrl,
                          hint: 'Main instruction text...', maxLines: 4),
                      const SizedBox(height: 14),
                      _editField('✅ English Note', eng2Ctrl,
                          hint: 'Thank you note...'),
                      const SizedBox(height: 14),
                      _editField('🌍 Urdu Instruction', urdu1Ctrl,
                          hint: 'اردو ہدایات...', maxLines: 3, rtl: true),
                      const SizedBox(height: 14),
                      _editField('⚠️ Urdu Warning', urdu2Ctrl,
                          hint: 'اردو وارننگ...', rtl: true),
                      const SizedBox(height: 24),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brand,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            setState(() {
                              _number      = numCtrl.text.trim().isEmpty   ? _number      : numCtrl.text.trim();
                              _engInstr    = eng1Ctrl.text.trim().isEmpty  ? _engInstr    : eng1Ctrl.text.trim();
                              _engNote     = eng2Ctrl.text.trim().isEmpty  ? _engNote     : eng2Ctrl.text.trim();
                              _urduInstr   = urdu1Ctrl.text.trim().isEmpty ? _urduInstr   : urdu1Ctrl.text.trim();
                              _urduWarning = urdu2Ctrl.text.trim().isEmpty ? _urduWarning : urdu2Ctrl.text.trim();
                            });
                            await _saveAll();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Saved successfully!',
                                  style: GoogleFonts.sora(
                                      color: Colors.white, fontWeight: FontWeight.w600)),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ));
                          },
                          child: Text('Save Changes',
                              style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl,
      {String hint = '', int maxLines = 1,
      TextInputType keyboardType = TextInputType.text, bool rtl = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.sora(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.sora(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.sora(color: Colors.grey[400], fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.brand, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Online Payment',
            style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppTheme.brandDark,
        foregroundColor: Colors.white,
        elevation: 0,
        // Edit button — only for admin
        actions: widget.isAdmin
            ? [
                GestureDetector(
                  onTap: _openEditSheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text('Edit',
                            style: GoogleFonts.sora(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              // EasyPaisa Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                      blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.phone_android_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('EasyPaisa', style: GoogleFonts.sora(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text('Karim Nagar Society',
                      style: GoogleFonts.sora(
                          color: Colors.white.withOpacity(0.7), fontSize: 13)),
                  const SizedBox(height: 20),
                  // Number box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_number, style: GoogleFonts.sora(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _number));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Number copied!',
                                style: GoogleFonts.sora(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.copy_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // Instructions Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: [BoxShadow(
                      color: AppTheme.brand.withOpacity(0.06),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // English
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language_rounded,
                          color: AppTheme.brand, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text('Instructions (English)',
                        style: GoogleFonts.sora(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                  ]),
                  const SizedBox(height: 12),
                  _InstructionLine(
                    icon: Icons.info_outline_rounded,
                    color: AppTheme.brand,
                    text: _engInstr,
                  ),
                  const SizedBox(height: 6),
                  _InstructionLine(
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.gold,
                    text: _engNote,
                  ),

                  const SizedBox(height: 20),
                  Divider(color: AppTheme.divider),
                  const SizedBox(height: 16),

                  // Urdu
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.translate_rounded,
                          color: AppTheme.success, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text('ہدایات (اردو)',
                        style: GoogleFonts.sora(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(
                        _urduInstr,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.notoNaskhArabic(
                            fontSize: 14, color: AppTheme.textPrimary,
                            height: 1.8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _urduWarning,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.notoNaskhArabic(
                            fontSize: 13,
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w700,
                            height: 1.8),
                      ),
                    ]),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // Steps card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.brand.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.brand.withOpacity(0.15)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('How to Pay', style: GoogleFonts.sora(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
                  const SizedBox(height: 14),
                  _StepRow(num: '1', text: 'Open EasyPaisa app'),
                  _StepRow(num: '2', text: 'Send money to $_number'),
                  _StepRow(num: '3', text: 'IKHLAQ AHMED name will appear '),
                  _StepRow(num: '3', text: 'Take screenshot of payment'),
                  _StepRow(num: '4', text: 'Send screenshot to same number on WhatsApp'),
                  _StepRow(num: '5', text: 'Collect your maintenance voucher ✅'),
                ]),
              ),

              const SizedBox(height: 30),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InstructionLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InstructionLine(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: GoogleFonts.sora(
              fontSize: 12, color: AppTheme.textPrimary, height: 1.6)),
        ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String num, text;
  const _StepRow({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: AppTheme.brand,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(num, style: GoogleFonts.sora(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.sora(
            fontSize: 12, color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
