import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'society_data.dart';
import 'maintenance_screen.dart';
import 'online_payment_screen.dart';
import 'login_screen.dart';
import 'notification_service.dart';

class ResidentDashboard extends StatefulWidget {
  final String houseId;
  const ResidentDashboard({super.key, required this.houseId});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic> _userData = {};
  StreamSubscription? _dataSub;
  StreamSubscription? _paymentsSub;
  List<Map<String, dynamic>> _paymentsList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _listenData();
    _listenPayments();
    _refreshSocietyData();
    _scheduleNotification();
  }

  void _listenPayments() {
    _paymentsSub = FirebaseFirestore.instance
        .collection('payments')
        .where('house', isEqualTo: widget.houseId)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        final Map<String, Map<String, dynamic>> periodMap = {};
        for (final doc in snap.docs) {
          final d = doc.data();
          final period = (d['period'] ?? '').toString();
          final month  = (d['month']  ?? '').toString();
          final year   = (d['year']   ?? '').toString();
          final amt    = (d['amount'] as num?)?.toDouble() ?? 700.0;
          if (periodMap.containsKey(period)) {
            periodMap[period]!['amount'] =
                (periodMap[period]!['amount'] as double) + amt;
          } else {
            periodMap[period] = {
              'id':     doc.id,
              'house':  d['house'] ?? '',
              'period': period,
              'month':  month,
              'year':   year,
              'date':   (d['date']  ?? '').toString(),
              'amount': amt,
              'img':    (d['img']   ?? '').toString(),
            };
          }
        }
        final list = periodMap.values.toList();
        list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
        setState(() => _paymentsList = list);
        _checkAndNotify();
      }
    });
  }

  Future<void> _refreshSocietyData() async {
    await SocietyData.refreshAll();
    if (mounted) setState(() {});
  }

  void _scheduleNotification() async {
    await NotificationService.init();
    await NotificationService.requestPermissions();
  }

  void _checkAndNotify() {
    if (_loading) return;
    final dues = _getPendingDues();
    if (dues.isEmpty) {
      NotificationService.cancelAllForHouse(widget.houseId);
      return;
    }
    final dueMonths = dues
        .map((d) => '${d['monthName']} ${d['year']}')
        .toList();
    NotificationService.handleDuesNotification(
      houseId: widget.houseId,
      allDues: dueMonths,
      totalDues: _duesAmount,
    );
  }

  void _listenData() {
    _dataSub = FirebaseFirestore.instance
        .collection('users')
        .where('house', isEqualTo: widget.houseId)
        .snapshots()
        .listen((snap) {
      if (mounted && snap.docs.isNotEmpty) {
        setState(() {
          _userData = snap.docs.first.data();
          _loading = false;
        });
        _checkAndNotify();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _paymentsSub?.cancel();
    super.dispose();
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_house_id');
    await prefs.remove('saved_password');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── Dues calculation ──
  // Paid months from BOTH sources: payments collection + old duesByYear
  Set<String> get _paidMonthYearSet {
    final paid = <String>{};
    // NEW: payments collection
    for (final p in _paymentsList) {
      final m = (p['month'] ?? '').toString().trim();
      final y = (p['year']  ?? '').toString().trim();
      if (m.isNotEmpty && y.isNotEmpty) paid.add('$m-$y');
    }
    // OLD: duesByYear from users collection
    final duesByYear = _userData['duesByYear'] as Map<String, dynamic>? ?? {};
    for (final yearEntry in duesByYear.entries) {
      final y = yearEntry.key;
      final monthMap = yearEntry.value as Map<String, dynamic>? ?? {};
      for (final monthEntry in monthMap.entries) {
        if (monthEntry.value == true) paid.add('${monthEntry.key}-$y');
      }
    }
    return paid;
  }

  List<Map<String, dynamic>> _getPendingDues() {
    final now = DateTime.now();
    final paidSet = _paidMonthYearSet;
    const monthNames = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    final dues = <Map<String, dynamic>>[];
    for (int y = 2026; y <= now.year; y++) {
      final maxM = y == now.year ? now.month : 12;
      for (int m = 1; m <= maxM; m++) {
        if (!paidSet.contains('${monthNames[m-1]}-$y')) {
          dues.add({'year': y, 'month': m, 'monthName': monthNames[m-1]});
        }
      }
    }
    return dues;
  }

  // ── Recent payments ──
  List<Map<String, dynamic>> _getRecentPayments() {
    return _paymentsList.take(10).toList();
  }

  String _lastPaymentLabel() {
    if (_paymentsList.isEmpty) return 'None';
    final p = _paymentsList.first;
    final month = (p['month'] ?? '').toString().trim();
    if (month.isNotEmpty) return month.length > 3 ? month.substring(0, 3) : month;
    final period = (p['period'] ?? '').toString().trim();
    if (period.isNotEmpty) {
      final parts = period.split(',');
      final last = parts.last.trim();
      return last.length > 3 ? last.substring(0, 3) : last;
    }
    return 'Paid';
  }

  double get _duesAmount => _getPendingDues().length * 700.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F5F7),
      drawer: _buildDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHero()),
                SliverToBoxAdapter(child: _buildCards()),
                SliverToBoxAdapter(child: _buildRecentPayments()),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );
  }

  // ── DRAWER ──────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF003D99),
        child: Column(
          children: [
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Center(child: Text('🏠', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'House ${widget.houseId}',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Resident Portal',
                          style: GoogleFonts.sora(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _drawerItem('🔧', 'Maintenance Team', 'View team members', const Color(0xFF6554C0), () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen()));
                  }),
                  _drawerItem('📋', 'Payment History', 'Receipts & vouchers', const Color(0xFF2684FF), () {
                    Navigator.pop(context);
                    _showPaymentHistory();
                  }),
                  _drawerItem('📄', 'Download PDF', '1-Year history report', const Color(0xFF36B37E), () {
                    Navigator.pop(context);
                    _downloadPdf();
                  }),
                  _drawerItem('🔑', 'Password Reset', 'Reset via Email OTP', const Color(0xFFFFAB00), () {
                    Navigator.pop(context);
                    _showResetPassword();
                  }),
                  _drawerItem('💳', 'Online Payment', 'EasyPaisa info', const Color(0xFF36B37E), () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnlinePaymentScreen(isAdmin: false)),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🚪', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: GoogleFonts.sora(
                          color: Colors.red[300],
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(String emoji, String label, String sub, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(sub, style: GoogleFonts.sora(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            const Text('›', style: TextStyle(color: Colors.white30, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  // ── HERO ────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003D99), Color(0xFF0052CC), Color(0xFF2684FF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: GoogleFonts.sora(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          'Resident Portal',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏠', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'House ${widget.houseId}',
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CARDS GRID ───────────────────────────────────────────
  Widget _buildCards() {
    final dues = _getPendingDues();
    final hasDues = dues.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _resCard(
                  icon: '💳',
                  iconBg: const Color(0xFF36B37E).withOpacity(0.12),
                  value: _lastPaymentLabel(),
                  valueColor: const Color(0xFF36B37E),
                  label: 'Last Payment',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _resCard(
                  icon: '📅',
                  iconBg: const Color(0xFF0052CC).withOpacity(0.1),
                  value: 'Rs.700',
                  valueColor: const Color(0xFF0052CC),
                  label: 'Monthly Fee',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDuesCard(dues, hasDues),
        ],
      ),
    );
  }

  Widget _buildDuesCard(List<Map<String, dynamic>> dues, bool hasDues) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasDues
            ? const Color(0xFFFF5630).withOpacity(0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasDues
              ? const Color(0xFFFF5630).withOpacity(0.25)
              : const Color(0xFFEBECF0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052CC).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hasDues
                      ? const Color(0xFFFF5630).withOpacity(0.1)
                      : const Color(0xFF36B37E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                    child: Text(hasDues ? '⚠️' : '✅',
                        style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDues ? 'Dues Pending' : 'No Dues',
                      style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: hasDues
                              ? const Color(0xFFFF5630)
                              : const Color(0xFF36B37E)),
                    ),
                    Text(
                      hasDues
                          ? '${dues.length} month(s) unpaid'
                          : 'All clear!',
                      style: GoogleFonts.sora(
                          fontSize: 10, color: const Color(0xFF8993A4)),
                    ),
                  ],
                ),
              ),
              Text(
                hasDues ? 'Rs.${_duesAmount.toInt()}' : 'Rs.0',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: hasDues
                      ? const Color(0xFFFF5630)
                      : const Color(0xFF36B37E),
                ),
              ),
            ],
          ),
          if (hasDues) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEBECF0)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dues.map((d) {
                final mn =
                    (d['monthName'] as String).substring(0, 3);
                final y = d['year'].toString().substring(2);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFF5630).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFF5630)
                            .withOpacity(0.25)),
                  ),
                  child: Text(
                    "$mn'$y",
                    style: GoogleFonts.sora(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF5630)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resCard({
    required String icon,
    required Color iconBg,
    required String value,
    required Color valueColor,
    required String label,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEBECF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052CC).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor),
              ),
              Text(
                label,
                style: GoogleFonts.sora(fontSize: 10, color: const Color(0xFF8993A4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── RECENT PAYMENTS ──────────────────────────────────────
  Widget _buildRecentPayments() {
    final payments = _getRecentPayments();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Text('Recent Payments',
              style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700,
                  color: const Color(0xFF172B4D))),
            const Spacer(),
            if (payments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF36B37E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${payments.length} records',
                    style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700,
                        color: const Color(0xFF36B37E))),
              ),
          ]),
        ),
        if (payments.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEBECF0)),
            ),
            child: Center(child: Column(children: [
              const Text('💳', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text('No payments yet', style: GoogleFonts.sora(
                  color: const Color(0xFF8993A4), fontSize: 13)),
            ])),
          )
        else
          ...payments.take(3).map((p) {
            final period = p['period']?.toString() ?? '';
            final dateStr = p['date']?.toString() ?? '';
            final amt = (p['amount'] as num?)?.toDouble() ?? 700.0;
            final imgUrl = p['img']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEBECF0)),
                boxShadow: [BoxShadow(color: const Color(0xFF36B37E).withOpacity(0.06),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF36B37E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text('✅', style: TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(period.isNotEmpty ? period : 'Payment',
                              style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 13),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('Paid: $dateStr',
                              style: GoogleFonts.sora(fontSize: 11, color: const Color(0xFF8993A4))),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Rs.${amt.toStringAsFixed(0)}',
                            style: GoogleFonts.sora(fontWeight: FontWeight.w800,
                                color: const Color(0xFF36B37E), fontSize: 14)),
                          if (imgUrl.isNotEmpty)
                            Text('📎 Voucher', style: GoogleFonts.sora(
                                fontSize: 9, color: const Color(0xFF0052CC),
                                fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),
                  ),
                  if (imgUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        barrierColor: Colors.black87,
                        builder: (_) => GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Dialog(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(imgUrl,
                                    fit: BoxFit.contain, width: 320),
                              ),
                              const SizedBox(height: 10),
                              Text('Tap to close', style: GoogleFonts.sora(
                                  color: Colors.white54, fontSize: 11)),
                            ]),
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        height: 140, width: double.infinity,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEBECF0))),
                        child: Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(imgUrl,
                                width: double.infinity, height: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, prog) =>
                                    prog == null ? child : const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2)),
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_rounded, color: Colors.grey))),
                          ),
                          Positioned(top: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF0052CC).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('Payment Voucher', style: GoogleFonts.sora(
                                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            )),
                          Positioned(bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('Tap to enlarge', style: GoogleFonts.sora(
                                  color: Colors.white, fontSize: 9)),
                            )),
                        ]),
                      ),
                    ),
                ],
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── PAYMENT HISTORY DIALOG ───────────────────────────────
  void _showPaymentHistory() {
    final payments = _getRecentPayments();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F5F7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Payment History',
                style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: payments.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('💳', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text('No payment history yet',
                        style: GoogleFonts.sora(color: const Color(0xFF8993A4), fontSize: 14)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    itemCount: payments.length,
                    itemBuilder: (_, i) {
                      final p = payments[i];
                      final period  = p['period']?.toString() ?? '';
                      final dateStr = p['date']?.toString() ?? '';
                      final amt     = (p['amount'] as num?)?.toDouble() ?? 700.0;
                      final imgUrl  = p['img']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEBECF0)),
                        ),
                        child: Column(children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF36B37E).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(child: Text('✅', style: TextStyle(fontSize: 18))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(period.isNotEmpty ? period : 'Payment',
                                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 13),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('Paid: $dateStr',
                                    style: GoogleFonts.sora(fontSize: 11, color: const Color(0xFF8993A4))),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('Rs.${amt.toStringAsFixed(0)}',
                                    style: GoogleFonts.sora(fontWeight: FontWeight.w800,
                                        color: const Color(0xFF36B37E), fontSize: 14)),
                                if (imgUrl.isNotEmpty)
                                  Text('📎 Receipt', style: GoogleFonts.sora(
                                      fontSize: 9, color: const Color(0xFF0052CC),
                                      fontWeight: FontWeight.w600)),
                              ]),
                            ]),
                          ),
                          if (imgUrl.isNotEmpty)
                            GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                barrierColor: Colors.black87,
                                builder: (_) => GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Dialog(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.network(imgUrl,
                                            fit: BoxFit.contain, width: 320),
                                      ),
                                      const SizedBox(height: 10),
                                      Text('Tap to close', style: GoogleFonts.sora(
                                          color: Colors.white54, fontSize: 11)),
                                    ]),
                                  ),
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                height: 140, width: double.infinity,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFEBECF0))),
                                child: Stack(children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.network(imgUrl,
                                        width: double.infinity, height: double.infinity,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (_, child, prog) =>
                                            prog == null ? child : const Center(
                                                child: CircularProgressIndicator(strokeWidth: 2)),
                                        errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.broken_image_rounded, color: Colors.grey))),
                                  ),
                                  Positioned(top: 8, left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF0052CC).withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text('Payment Voucher', style: GoogleFonts.sora(
                                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                                    )),
                                  Positioned(bottom: 8, right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text('Tap to enlarge', style: GoogleFonts.sora(
                                          color: Colors.white, fontSize: 9)),
                                    )),
                                ]),
                              ),
                            ),
                        ]),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DOWNLOAD PDF ─────────────────────────────────────────
  Future<void> _downloadPdf() async {
    final pdf = pw.Document();
    final payments = _getRecentPayments();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Karim Nagar Society — House ${widget.houseId}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Payment History Report', style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            pw.Divider(),
            ...payments.map((p) {
              final months = p['period']?.toString() ?? '';
              final dateStr = p['date']?.toString() ?? '';
              final amt = (p['amount'] as num?)?.toDouble() ?? 700.0;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(months)),
                    pw.Text(dateStr),
                    pw.Text('Rs.$amt', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  // ── RESET PASSWORD — Email OTP Flow ─────────────────────
  void _showResetPassword() {
    // Step 1: get user email from Firestore
    final emailDoc = (_userData['email'] ?? '').toString().trim();
    if (emailDoc.isEmpty || emailDoc == 'Not Registered') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email registered. Contact admin.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    _showOtpStep1(emailDoc);
  }

  void _showOtpStep1(String email) {
    String generatedOtp = '';
    bool sending = false;

    // Generate 6-digit OTP
    final otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    generatedOtp = otp;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0052CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.email_rounded, color: Color(0xFF0052CC), size: 26),
            ),
            const SizedBox(height: 10),
            Text('Reset Password', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text('OTP sent to: $email',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w400,
                    color: Colors.grey)),
          ]),
          content: sending
              ? const SizedBox(height: 40,
                  child: Center(child: CircularProgressIndicator()))
              : const SizedBox.shrink(),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.sora(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
              onPressed: sending ? null : () async {
                setS(() => sending = true);
                // Send OTP via EmailJS
                await _sendOtpEmail(email, generatedOtp);
                Navigator.pop(ctx);
                if (mounted) _showOtpStep2(email, generatedOtp);
              },
              child: Text('Send OTP', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _sendOtpEmail(String toEmail, String otp) async {
    try {
      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json', 'origin': 'http://localhost'},
        body: jsonEncode({
          'service_id': 'service_karim_nagar',
          'template_id': 'template_otp_reset',
          'user_id': 'YOUR_EMAILJS_PUBLIC_KEY',
          'template_params': {
            'to_email': toEmail,
            'otp_code': otp,
            'house_id': widget.houseId,
          },
        }),
      );
    } catch (_) {}
  }

  void _showOtpStep2(String email, String correctOtp) {
    final otpCtrl = TextEditingController();
    bool error = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.sms_rounded, color: Color(0xFFFF9800), size: 26),
            ),
            const SizedBox(height: 10),
            Text('Enter OTP', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text('Code sent to: $email',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 12, color: Colors.grey)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800,
                  letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '------',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0052CC), width: 2)),
                errorText: error ? 'Wrong OTP, try again' : null,
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.sora(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
              onPressed: () {
                if (otpCtrl.text.trim() == correctOtp) {
                  Navigator.pop(ctx);
                  if (mounted) _showOtpStep3();
                } else {
                  setS(() => error = true);
                }
              },
              child: Text('Verify', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  void _showOtpStep3() {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true;
    bool error = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF36B37E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFF36B37E), size: 26),
            ),
            const SizedBox(height: 10),
            Text('New Password', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 17)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: passCtrl,
              obscureText: obscure1,
              decoration: InputDecoration(
                hintText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                    icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure1 = !obscure1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: obscure2,
              decoration: InputDecoration(
                hintText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                    icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure2 = !obscure2)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: error ? 'Passwords do not match' : null,
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.sora(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF36B37E)),
              onPressed: () async {
                final np = passCtrl.text.trim();
                final cp = confirmCtrl.text.trim();
                if (np.isEmpty || np != cp) {
                  setS(() => error = true);
                  return;
                }
                // Save to Firestore
                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .where('house', isEqualTo: widget.houseId)
                    .get();
                if (snap.docs.isNotEmpty) {
                  await snap.docs.first.reference.update({'password': np});
                }
                // Also update SocietyData in memory
                final idx = SocietyData.userRecords.indexWhere(
                    (r) => r['house'] == widget.houseId);
                if (idx != -1) SocietyData.userRecords[idx]['pass'] = np;

                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Password changed successfully!',
                            style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
                      ]),
                      backgroundColor: const Color(0xFF36B37E),
                    ),
                  );
                }
              },
              child: Text('Save', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }
}
