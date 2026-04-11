// lib/screens/house_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'society_data.dart';
import 'cloudinary_service.dart';

// Admin ID globally pass hoga (login ke waqt set hoga)
String currentAdminId = 'ADMIN';

class HouseDetailScreen extends StatefulWidget {
  final String houseId;
  final bool isAdminView;

  const HouseDetailScreen({
    super.key,
    required this.houseId,
    this.isAdminView = true,
  });

  @override
  State<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends State<HouseDetailScreen> {
  DateTime _date = DateTime.now();
  // Multi-year selection: {'month': 'January', 'year': '2025'}
  List<Map<String, dynamic>> _selectedMonthsWithYear = [];
  XFile? _voucherImage;
  bool _submitting = false;
  bool _amtManuallyEdited = false;
  final _amtCtrl = TextEditingController(text: '0');
  final _picker   = ImagePicker();

  final List<String> _months = [
    'January','February','March','April',
    'May','June','July','August',
    'September','October','November','December'
  ];
  // Show 2025 aur aage ke years
  final List<String> _years = [
    '2025','2026','2027','2028','2029','2030'
  ];
  String _viewYear = '2025'; // Year selector for month grid

  Future<void> _pickImage() async {
    // Show camera or gallery option
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Upload Voucher', style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          ListTile(
            leading: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_rounded, color: AppTheme.brand)),
            title: Text('Take Photo', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
            subtitle: Text('Open camera to click voucher',
                style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library_rounded, color: AppTheme.success)),
            title: Text('Choose from Gallery', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
            subtitle: Text('Select existing photo from gallery',
                style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;
    final f = await _picker.pickImage(source: source, imageQuality: 50, maxWidth: 1024);
    if (f != null) setState(() => _voucherImage = f);
  }

  // Auto-calculate amount when months change
  void _recalcAmount() {
    if (!_amtManuallyEdited) {
      final total = _selectedMonthsWithYear.length * SocietyData.monthlyFee;
      _amtCtrl.text = total.toStringAsFixed(0);
    }
  }

  void _toggleMonth(String month, String year) {
    setState(() {
      final exists = _selectedMonthsWithYear
          .any((e) => e['month'] == month && e['year'] == year);
      if (exists) {
        _selectedMonthsWithYear.removeWhere(
            (e) => e['month'] == month && e['year'] == year);
      } else {
        _selectedMonthsWithYear.add({'month': month, 'year': year});
      }
      _recalcAmount();
    });
  }

  bool _isMonthSelected(String month, String year) =>
      _selectedMonthsWithYear.any((e) => e['month'] == month && e['year'] == year);

  Future<void> _submit() async {
    if (_selectedMonthsWithYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select at least one month!', style: GoogleFonts.sora()),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _submitting = true);

    final amt     = double.tryParse(_amtCtrl.text) ?? SocietyData.monthlyFee;
    final dateStr =
        '${_date.day.toString().padLeft(2,'0')}/${_date.month.toString().padLeft(2,'0')}/${_date.year}';

    // Capture values before clearing state
    final selectedMonths   = List<Map<String, dynamic>>.from(_selectedMonthsWithYear);
    final voucherImagePath = _voucherImage?.path;

    // Show saving snackbar (loading state)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 12),
        Text('Saving payment...', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: AppTheme.brand,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    // Upload voucher image if selected
    String voucherUrl = '';
    if (voucherImagePath != null) {
      voucherUrl = await CloudinaryService.uploadImage(File(voucherImagePath), folder: 'vouchers');
    }

    // Save to Firebase — AWAIT properly taake record save ho jaye
    final alreadyPaid = await SocietyData.addPaymentMultiYear(
      house:           widget.houseId,
      monthsWithYears: selectedMonths,
      amount:          amt,
      date:            dateStr,
      imgPath:         voucherUrl,
      adminId:         currentAdminId,
    );

    if (!mounted) return;

    // Clear UI AFTER successful save
    setState(() {
      _selectedMonthsWithYear.clear();
      _voucherImage        = null;
      _amtManuallyEdited   = false;
      _amtCtrl.text        = '0';
      _submitting          = false;
    });

    // Dismiss loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (alreadyPaid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Already Paid: ${alreadyPaid.join(', ')}',
            style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12))),
        ]),
        backgroundColor: const Color(0xFFFFB703),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    // Success — record saved ho gaya, ab confirm karein
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text('Payment saved successfully!',
            style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: const Color(0xFF36B37E),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Edit dialog ────────────────────────────────────────────────────
  void _showEditDialog(int index) {
    final hist     = SocietyData.getHistory(widget.houseId);
    final item     = hist[index];
    final amtCtrl  = TextEditingController(text: item['amount']);
    final dateCtrl = TextEditingController(text: item['date']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Edit Record', style: GoogleFonts.sora(fontSize: 18,
                fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text(item['period'] ?? '',
                style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            TextField(controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Date (dd/MM/yyyy)',
                    prefixIcon: Icon(Icons.calendar_today_rounded))),
            const SizedBox(height: 12),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (Rs.)',
                    prefixIcon: Icon(Icons.payments_rounded))),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Cancel', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: () async {
                  setState(() {
                    SocietyData.houseHistory[widget.houseId]![index]['amount'] = amtCtrl.text;
                    SocietyData.houseHistory[widget.houseId]![index]['date']   = dateCtrl.text;
                  });
                  await SocietyData.savePaymentEdit(
                      widget.houseId, index, dateCtrl.text, amtCtrl.text,
                      adminId: currentAdminId);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSuccess('Record updated!');
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Save Changes', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
              )),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Delete payment confirm ─────────────────────────────────────────
  void _showDeleteConfirm(int index) {
    final hist = SocietyData.getHistory(widget.houseId);
    final item = hist[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 20)),
          const SizedBox(width: 12),
          Text('Delete Payment?', style: GoogleFonts.sora(fontSize: 16,
              fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This payment will be permanently deleted:',
              style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.danger.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['period'] ?? '', style: GoogleFonts.sora(fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary, fontSize: 13)),
              Text('Rs. ${item['amount']} | ${item['date']}',
                  style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
            ]),
          ),
          const SizedBox(height: 8),
          Text('⚠️ This action cannot be undone!',
              style: GoogleFonts.sora(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.sora(color: AppTheme.textMuted, fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await SocietyData.deletePayment(
                  house: widget.houseId, histIndex: index, adminId: currentAdminId);
              if (!mounted) return;
              setState(() {});
              _showSuccess('Payment deleted!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Delete', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Voucher options: change / delete ──────────────────────────────
  void _showVoucherOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Voucher Options', style: GoogleFonts.sora(fontSize: 16,
              fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.brand, size: 22)),
            title: Text('Change Voucher', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
            subtitle: Text('Select new voucher from gallery',
                style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
            onTap: () async {
              Navigator.pop(context);
              // Camera or Gallery
              final source = await showModalBottomSheet<ImageSource>(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.brand),
                      title: Text('Take Photo', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library_rounded, color: AppTheme.success),
                      title: Text('Choose from Gallery', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              );
              if (source == null) return;
              final f = await _picker.pickImage(source: source, imageQuality: 50, maxWidth: 1024);
              if (f != null) {
                _showInfo('Uploading voucher...');
                final url = await CloudinaryService.uploadImage(
                    File(f.path), folder: 'vouchers');
                await SocietyData.updateVoucher(
                    house: widget.houseId, histIndex: index,
                    newImgPath: url.isNotEmpty ? url : f.path,
                    adminId: currentAdminId);
                if (!mounted) return;
                setState(() {});
                _showSuccess(url.isNotEmpty ? 'Voucher uploaded!' : 'Saved (offline)');
              }
            },
          ),
          ListTile(
            leading: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 22)),
            title: Text('Delete Voucher', style: GoogleFonts.sora(
                fontWeight: FontWeight.w700, color: AppTheme.danger)),
            subtitle: Text('The voucher image will be removed',
                style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
            onTap: () async {
              Navigator.pop(context);
              await SocietyData.updateVoucher(
                  house: widget.houseId, histIndex: index,
                  newImgPath: '', adminId: currentAdminId);
              if (!mounted) return;
              setState(() {});
              _showSuccess('Voucher deleted!');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showVoucher(String path) {
    if (path.isEmpty) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _VoucherViewerScreen(imagePath: path)));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg, style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 4,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 14),
        Text(msg, style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
      backgroundColor: AppTheme.brand,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('house', isEqualTo: widget.houseId)
          .snapshots(),
      builder: (context, snap) {
        // Build history from live Firestore data
        List<Map<String, String>> history = [];
        if (snap.hasData) {
          // Group by period to avoid duplicates
          // (3 months payment = 3 docs in Firebase, same period)
          final Map<String, Map<String, String>> periodMap = {};
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final period = (d['period'] ?? '').toString();
            final date   = (d['date']   ?? '').toString();
            final img    = (d['img']    ?? '').toString();
            final house  = (d['house']  ?? '').toString();
            // Calculate total amount for this period
            final amt = (d['amount'] as num?)?.toDouble() ?? 700.0;

            if (periodMap.containsKey(period)) {
              // Add amount for same period
              final existing = periodMap[period]!;
              final existingAmt = double.tryParse(existing['amount'] ?? '0') ?? 0;
              periodMap[period]!['amount'] = (existingAmt + amt).toStringAsFixed(0);
            } else {
              periodMap[period] = {
                'id':     doc.id,
                'period': period,
                'date':   date,
                'amount': amt.toStringAsFixed(0),
                'img':    img,
                'house':  house,
              };
            }
          }
          history = periodMap.values.toList();
          history.sort((a, b) => b['date']!.compareTo(a['date']!));

          // Also update SocietyData in memory for other screens
          SocietyData.houseHistory[widget.houseId] = history;
        }

        return Scaffold(
      appBar: AppBar(
        title: Text('House ${widget.houseId}'),
        backgroundColor: AppTheme.brandDark,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${history.length} records', style: GoogleFonts.sora(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          if (widget.isAdminView)  _buildForm(),
          if (!widget.isAdminView) _buildResidentBanner(history),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Payment History', style: GoogleFonts.sora(fontSize: 15,
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              if (history.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${history.length} records', style: GoogleFonts.sora(
                      fontSize: 11, color: AppTheme.brand, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          if (!snap.hasData)
            const Padding(padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()))
          else if (history.isEmpty)
            Padding(padding: const EdgeInsets.all(40),
              child: Column(children: [
                const Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text('No payment records yet', style: GoogleFonts.sora(color: AppTheme.textMuted)),
              ]))
          else
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (_, i) => _HistoryCard(
                item: history[i],
                isAdminView: widget.isAdminView,
                onEdit:         widget.isAdminView ? () => _showEditDialog(i)      : null,
                onDelete:       widget.isAdminView ? () => _showDeleteConfirm(i)   : null,
                onVoucherEdit:  widget.isAdminView ? () => _showVoucherOptions(i)  : null,
                onViewVoucher:  () => _showVoucher(history[i]['img'] ?? ''),
              ),
            ),
        ]),
      ),
        );
      },
    );
  }

  Widget _buildResidentBanner(List<Map<String, String>> history) {
    final lastPaid = history.isNotEmpty ? history.first : null;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.brandDark, AppTheme.brand],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.brand.withOpacity(0.25),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.25))),
            child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 26)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('House ${widget.houseId}', style: GoogleFonts.sora(color: Colors.white,
              fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(lastPaid != null ? 'Last paid: ${lastPaid['period']}' : 'No payment recorded yet',
              style: GoogleFonts.sora(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: lastPaid != null ? AppTheme.success.withOpacity(0.25) : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lastPaid != null
                ? AppTheme.success.withOpacity(0.5) : Colors.white.withOpacity(0.2)),
          ),
          child: Text(lastPaid != null ? '✓ PAID' : 'PENDING', style: GoogleFonts.sora(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _buildForm() {
    // Lifetime total
    final lifetimeTotal = SocietyData.getTotalPaidAllTime(widget.houseId);
    final lifetimeMonths = SocietyData.getTotalPaidMonthsCount(widget.houseId);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: AppTheme.brand.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──
        Row(children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(
              color: AppTheme.brand, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text('Add Payment', style: GoogleFonts.sora(fontSize: 15,
              fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(currentAdminId, style: GoogleFonts.sora(fontSize: 10,
                fontWeight: FontWeight.w700, color: AppTheme.brand)),
          ),
        ]),

        // ── Lifetime Total Banner ──
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.brandDark, AppTheme.brand],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Paid to Date', style: GoogleFonts.sora(
                  color: Colors.white.withOpacity(0.75), fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              Text('Rs. ${lifetimeTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.sora(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$lifetimeMonths', style: GoogleFonts.sora(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text('months paid', style: GoogleFonts.sora(
                  color: Colors.white.withOpacity(0.7), fontSize: 9)),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Date ──
        _miniTile('Date', DateFormat('dd/MM/yyyy').format(_date),
          Icons.calendar_today_rounded, () async {
            final p = await showDatePicker(context: context, initialDate: _date,
                firstDate: DateTime(2025), lastDate: DateTime(2030));
            if (p != null) setState(() => _date = p);
          }),

        const SizedBox(height: 16),

        // ── Year Tab Selector ──
        Text('Select Year & Month(s)', style: GoogleFonts.sora(fontSize: 11,
            fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 8),

        // Year tabs - scrollable
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _years.map((y) {
            final active = _viewYear == y;
            return GestureDetector(
              onTap: () => setState(() => _viewYear = y),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppTheme.brand : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppTheme.brand : AppTheme.divider),
                ),
                child: Text(y, style: GoogleFonts.sora(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppTheme.textSecondary)),
              ),
            );
          }).toList()),
        ),

        const SizedBox(height: 10),

        // Month chips for selected year
        Wrap(spacing: 7, runSpacing: 7,
          children: _months.map((m) {
            final sel     = _isMonthSelected(m, _viewYear);
            final alrPaid = SocietyData.isMonthPaid(widget.houseId, m, _viewYear);
            return GestureDetector(
              onTap: alrPaid ? null : () => _toggleMonth(m, _viewYear),
              child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: alrPaid
                      ? AppTheme.success.withOpacity(0.12)
                      : sel ? AppTheme.brand : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: alrPaid
                        ? AppTheme.success.withOpacity(0.4)
                        : sel ? AppTheme.brand : AppTheme.divider,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (alrPaid) ...[
                    const Icon(Icons.check_circle_rounded,
                        size: 11, color: AppTheme.success),
                    const SizedBox(width: 3),
                  ],
                  Text(m.substring(0, 3), style: GoogleFonts.sora(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: alrPaid
                          ? AppTheme.success
                          : sel ? Colors.white : AppTheme.textSecondary)),
                ]),
              ),
            );
          }).toList(),
        ),

        // Selected months summary
        if (_selectedMonthsWithYear.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.brand.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.brand.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.brand, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '${_selectedMonthsWithYear.length} months selected: ' +
                _selectedMonthsWithYear.map((e) =>
                    '${e['month']!.substring(0,3)} ${e['year']}').join(', '),
                style: GoogleFonts.sora(fontSize: 11, color: AppTheme.brand,
                    fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              )),
            ]),
          ),
        ],

        const SizedBox(height: 14),

        // ── Amount Field ──
        TextField(
          controller: _amtCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _amtManuallyEdited = true),
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15,
              color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Total Amount (Rs.)',
            prefixIcon: const Icon(Icons.payments_rounded, color: AppTheme.brand),
            helperText: _amtManuallyEdited
                ? 'Manual amount set'
                : '${_selectedMonthsWithYear.length} × Rs.${SocietyData.monthlyFee.toStringAsFixed(0)} = auto calculated',
            helperStyle: GoogleFonts.sora(
                fontSize: 10,
                color: _amtManuallyEdited ? AppTheme.gold : AppTheme.textMuted),
            suffixIcon: _amtManuallyEdited
                ? IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppTheme.brand, size: 18),
                    onPressed: () => setState(() {
                      _amtManuallyEdited = false;
                      _recalcAmount();
                    }),
                    tooltip: 'Reset to auto',
                  )
                : null,
          ),
        ),

        const SizedBox(height: 14),

        // ── Voucher Upload ──
        GestureDetector(
          onTap: _pickImage,
          child: Container(height: 80, width: double.infinity,
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _voucherImage != null ? AppTheme.success : AppTheme.divider,
                  width: _voucherImage != null ? 2 : 1)),
            child: _voucherImage == null
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_a_photo_rounded, color: AppTheme.brand, size: 22),
                    const SizedBox(width: 10),
                    Text('Upload Receipt / Voucher', style: GoogleFonts.sora(
                        fontSize: 12, color: AppTheme.brand, fontWeight: FontWeight.w600)),
                  ])
                : Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_voucherImage!.path),
                            width: double.infinity, height: double.infinity, fit: BoxFit.cover)),
                    Positioned(top: 6, right: 6,
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.success,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check, color: Colors.white, size: 12),
                            const SizedBox(width: 3),
                            Text('Receipt Added', style: GoogleFonts.sora(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          ]),
                        )),
                  ]),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_upload_rounded, size: 18),
                    const SizedBox(width: 8),
                    const Text('SUBMIT PAYMENT'),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _miniTile(String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.divider)),
        child: Row(children: [
          Icon(icon, size: 18, color: AppTheme.brand),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.sora(fontSize: 9, color: AppTheme.textMuted, letterSpacing: 0.5)),
            Text(value, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ]),
        ]),
      ),
    );
  }
}

// ─── Voucher Full Screen ───────────────────────────────────────────────────
class _VoucherViewerScreen extends StatelessWidget {
  final String imagePath;
  const _VoucherViewerScreen({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text('Payment Voucher', style: GoogleFonts.sora(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Center(child: InteractiveViewer(
        panEnabled: true, minScale: 0.5, maxScale: 5.0,
        child: _VoucherImage(
          imgSrc: imagePath,
          fit: BoxFit.contain,
          errorColor: Colors.white54,
        ),
      )),
    );
  }
}

// ─── History Card — delete + voucher edit buttons ─────────────────────────
class _HistoryCard extends StatelessWidget {
  final Map<String, String> item;
  final bool isAdminView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onVoucherEdit;
  final VoidCallback onViewVoucher;

  const _HistoryCard({
    required this.item, required this.isAdminView,
    required this.onEdit, required this.onDelete,
    required this.onVoucherEdit, required this.onViewVoucher,
  });

  @override
  Widget build(BuildContext context) {
    final hasVoucher = (item['img'] ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: AppTheme.brand.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
          leading: Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.receipt_long_rounded, color: AppTheme.brand, size: 22)),
          title: Text(item['period'] ?? '', style: GoogleFonts.sora(fontWeight: FontWeight.w700,
              fontSize: 13, color: AppTheme.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 11, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(item['date'] ?? '', style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(width: 10),
              const Icon(Icons.payments_rounded, size: 11, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text('Rs. ${item['amount']}', style: GoogleFonts.sora(fontSize: 11,
                  color: AppTheme.brand, fontWeight: FontWeight.w700)),
            ]),
          ),
          trailing: isAdminView ? Row(mainAxisSize: MainAxisSize.min, children: [
            // Edit button
            GestureDetector(onTap: onEdit,
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.edit_rounded, color: AppTheme.gold, size: 16)),
            ),
            const SizedBox(width: 6),
            // Voucher edit button
            GestureDetector(onTap: onVoucherEdit,
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.image_rounded, color: AppTheme.brand, size: 16)),
            ),
            const SizedBox(width: 6),
            // Delete button
            GestureDetector(onTap: onDelete,
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 16)),
            ),
          ]) : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasVoucher ? AppTheme.success.withOpacity(0.1) : AppTheme.divider.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(hasVoucher ? Icons.image_rounded : Icons.image_not_supported_rounded,
                  size: 13, color: hasVoucher ? AppTheme.success : AppTheme.textMuted),
              const SizedBox(width: 3),
              Text(hasVoucher ? 'Receipt' : 'No receipt', style: GoogleFonts.sora(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: hasVoucher ? AppTheme.success : AppTheme.textMuted)),
            ]),
          ),
        ),

        if (hasVoucher)
          GestureDetector(
            onTap: onViewVoucher,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              height: 160, width: double.infinity,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider), color: AppTheme.surface),
              child: Stack(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _VoucherImage(
                        imgSrc: item['img'] ?? '',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover)),
                Positioned(bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text('Tap to enlarge', style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    )),
                Positioned(top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.brand.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Payment Voucher', style: GoogleFonts.sora(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    )),
              ]),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.image_not_supported_rounded, size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text('No voucher uploaded for this payment',
                  style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted)),
            ]),
          ),
      ]),
    );
  }
}

// ── Smart Voucher Image Widget ──────────────────────────────────────────
// URL (http) → Network image (sab phones par dikhe)
// Local path → File image (sirf us phone par)
// Empty      → Placeholder
class _VoucherImage extends StatelessWidget {
  final String imgSrc;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color errorColor;

  const _VoucherImage({
    required this.imgSrc,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorColor = const Color(0xFF99A8BF),
  });

  @override
  Widget build(BuildContext context) {
    if (imgSrc.isEmpty) return _placeholder();

    // Firebase/Cloudinary URL — sab phones par dikhe gi
    if (imgSrc.startsWith('http')) {
      return Image.network(
        imgSrc,
        width: width, height: height, fit: fit,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Center(child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
            strokeWidth: 2, color: AppTheme.brand,
          ));
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    // Local file (fallback — sirf usi phone par)
    final f = File(imgSrc);
    if (f.existsSync()) {
      return Image.file(f,
          width: width, height: height, fit: fit,
          errorBuilder: (_, __, ___) => _placeholder());
    }

    return _placeholder();
  }

  Widget _placeholder() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.receipt_long_rounded, color: errorColor, size: 40),
      const SizedBox(height: 8),
      Text('Voucher nahi mila', style: TextStyle(color: errorColor, fontSize: 12)),
    ],
  ));
}