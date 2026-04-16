import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'society_data.dart';
import 'house_detail_screen.dart';
import 'house_list_screen.dart';
import 'analytics_screen.dart';
import 'maintenance_screen.dart';
import 'dues_list_screen.dart';
import 'online_payment_screen.dart';
import 'login_screen.dart';
import 'privacy_screen.dart';
import 'update_service.dart';

class AdminDashboard extends StatefulWidget {
  final String adminId;
  const AdminDashboard({super.key, required this.adminId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTab = 0; // 0=Houses, 1=Dues, 2=Payment
  // Search & Filter
  String _searchQuery = '';
  String? _filterYear;
  String? _filterMonth;
  bool _filterActive = false;
  String _filterType = 'unpaid'; // 'paid' or 'unpaid'
  final _searchCtrl = TextEditingController();
  OverlayEntry? _filterOverlay;
  List<Map<String, dynamic>> _activityLog = [];
  StreamSubscription? _logSub;

  @override
  StreamSubscription? _paymentsSub;

  void initState() {
    super.initState();
    _listenActivity();
    _listenPayments();
  }

  void _listenPayments() {
    // One-time refresh on startup, then rely on StreamBuilder
    SocietyData.refreshPayments().then((_) {
      if (mounted) setState(() {});
    });
  }

  List<Map<String, dynamic>> get _todayPayments {
    final now = DateTime.now();
    return _activityLog.where((log) {
      final action = (log['action'] ?? '').toString();
      if (!action.contains('Payment')) return false;
      final ts = log['timestamp'];
      if (ts == null) return false;
      DateTime? dt;
      try { dt = (ts as dynamic).toDate(); } catch (_) { return false; }
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
  }

  void _listenActivity() {
    // Get today's start timestamp
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    _logSub = FirebaseFirestore.instance
        .collection('activity_log')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _activityLog = snap.docs
              .map((d) => Map<String, dynamic>.from(d.data() as Map))
              .toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _searchCtrl.dispose();
    _filterOverlay?.remove();
    super.dispose();
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F5F7),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHero(),
          _buildTabs(),
          Expanded(child: _buildBody()),
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
            // Header
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
                      child: const Center(child: Text('⚙️', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.adminId.toUpperCase(),
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Admin Panel',
                          style: GoogleFonts.sora(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _drawerItem('🏠', 'House Records', '${SocietyData.allHouses.length} houses', const Color(0xFF2684FF), () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HouseListScreen()));
                  }),
                  _drawerItem('📊', 'Analytics', 'Monthly graph', const Color(0xFF36B37E), () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
                  }),
                  _drawerItem('👥', 'User Management', 'Passwords & email', const Color(0xFFFFAB00), () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                  }),
                  _drawerItem('🔑', 'Change Password', 'Admin password', const Color(0xFFFF5630), () {
                    Navigator.pop(context);
                    _showChangePasswordDialog();
                  }),
                  _drawerItem('🔧', 'Maintenance Team', '3 members', const Color(0xFF6554C0), () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen(isAdmin: true)));
                  }),
                  _drawerItem('📋', 'Dues List', 'View & download', const Color(0xFFFF5630), () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 1);
                  }),
                  _drawerItem('💳', 'Online Payment', 'EasyPaisa info', const Color(0xFF36B37E), () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 2);
                  }),
                  _drawerItem('📢', 'Update Notification', 'Sab users ko bhjao', const Color(0xFF0052CC), () {
                    Navigator.pop(context);
                    _showSendNotificationDialog();
                  }),
                ],
              ),
            ),
            // Logout
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent,
        ),
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
                  // Hamburger
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
                          'Admin · ${widget.adminId.toUpperCase()}',
                          style: GoogleFonts.sora(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          '${widget.adminId} Khan',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Logout
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
              // Search + Filter row
              Row(children: [
                // Search
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.sora(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search house...',
                        hintStyle: GoogleFonts.sora(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16))
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        fillColor: Colors.transparent,
                        filled: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter button
                GestureDetector(
                  onTap: () => _showFilterDropdown(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _filterActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _filterActive ? Colors.white : Colors.white24),
                    ),
                    child: Icon(Icons.filter_list_rounded,
                        color: _filterActive ? const Color(0xFF0052CC) : Colors.white,
                        size: 20),
                  ),
                ),
              ]),
              // Active filter chip
              if (_filterActive) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() { _filterYear = null; _filterMonth = null; _filterActive = false; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text('$_filterMonth $_filterYear  ✕',
                          style: GoogleFonts.sora(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🏠', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text('${SocietyData.allHouses.length} Houses',
                        style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── TABS ────────────────────────────────────────────────
  Widget _buildTabs() {
    final tabs = [
      ('🏠', 'Houses'),
      ('📋', 'Dues List'),
      ('💳', 'Payment'),
    ];
    return Container(
      color: const Color(0xFFF4F5F7),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = _selectedTab == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF0052CC) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: active ? const Color(0xFF0052CC) : const Color(0xFFEBECF0),
                  ),
                  boxShadow: active
                      ? [BoxShadow(color: const Color(0xFF0052CC).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Row(
                  children: [
                    Text(tabs[i].$1, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      tabs[i].$2,
                      style: GoogleFonts.sora(
                        color: active ? Colors.white : const Color(0xFF8993A4),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── BODY ────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_selectedTab) {
      case 0:
        return _buildHousesTab();
      case 1:
        return Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const DuesListScreen()),
        );
      case 2:
        return const OnlinePaymentScreen(isAdmin: true);
      default:
        return _buildHousesTab();
    }
  }

  // ── FILTER DROPDOWN ────────────────────────────────────
  void _showFilterDropdown(BuildContext context) {
    _filterOverlay?.remove();
    _filterOverlay = null;

    final months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    final now = DateTime.now();
    final years = List.generate(now.year - 2024, (i) => (2025 + i).toString());

    String tempYear  = _filterYear  ?? now.year.toString();
    String tempMonth = _filterMonth ?? months[now.month - 1];
    String tempType  = _filterType;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _filterOverlay = OverlayEntry(
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return Stack(children: [
            // Dismiss tap
            Positioned.fill(
              child: GestureDetector(
                onTap: () { _filterOverlay?.remove(); _filterOverlay = null; },
                child: Container(color: Colors.transparent),
              ),
            ),
            // Dropdown card
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 140,
              left: 16, right: 16,
              child: Material(
                elevation: 16,
                borderRadius: BorderRadius.circular(20),
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                        blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF003D99), Color(0xFF0052CC)]),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Filter by Month', style: GoogleFonts.sora(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () { _filterOverlay?.remove(); _filterOverlay = null; },
                          child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        // Year selector
                        Text('Year', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
                            color: const Color(0xFF99A8BF))),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: years.map((y) => GestureDetector(
                            onTap: () => setS(() => tempYear = y),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: tempYear == y ? const Color(0xFF0052CC) : const Color(0xFFF4F7FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tempYear == y
                                    ? const Color(0xFF0052CC) : const Color(0xFFE4EAF5)),
                              ),
                              child: Text(y, style: GoogleFonts.sora(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: tempYear == y ? Colors.white : const Color(0xFF0A1628))),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 16),
                        // Month grid
                        Text('Month', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
                            color: const Color(0xFF99A8BF))),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 6, mainAxisSpacing: 6,
                          childAspectRatio: 2.2,
                          children: months.map((m) {
                            final sel = tempMonth == m;
                            final short = m.substring(0, 3);
                            return GestureDetector(
                              onTap: () => setS(() => tempMonth = m),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: sel ? const Color(0xFF0052CC) : const Color(0xFFF4F7FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: sel
                                      ? const Color(0xFF0052CC) : const Color(0xFFE4EAF5)),
                                ),
                                child: Center(child: Text(short, style: GoogleFonts.sora(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : const Color(0xFF5B6B8A)))),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        // Paid / Unpaid selector
                        Text('Show', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
                            color: const Color(0xFF99A8BF))),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: GestureDetector(
                            onTap: () => setS(() => tempType = 'paid'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: tempType == 'paid' ? const Color(0xFF06D6A0) : const Color(0xFFF4F7FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tempType == 'paid'
                                    ? const Color(0xFF06D6A0) : const Color(0xFFE4EAF5)),
                              ),
                              child: Center(child: Text('✅ Paid', style: GoogleFonts.sora(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: tempType == 'paid' ? Colors.white : const Color(0xFF5B6B8A)))),
                            ),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: GestureDetector(
                            onTap: () => setS(() => tempType = 'unpaid'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: tempType == 'unpaid' ? const Color(0xFFEF233C) : const Color(0xFFF4F7FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tempType == 'unpaid'
                                    ? const Color(0xFFEF233C) : const Color(0xFFE4EAF5)),
                              ),
                              child: Center(child: Text('❌ Unpaid', style: GoogleFonts.sora(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: tempType == 'unpaid' ? Colors.white : const Color(0xFF5B6B8A)))),
                            ),
                          )),
                        ]),
                        const SizedBox(height: 16),
                        // Apply button
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _filterYear = null; _filterMonth = null; _filterActive = false;
                                });
                                _filterOverlay?.remove(); _filterOverlay = null;
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE4EAF5)),
                                ),
                                child: Center(child: Text('Clear', style: GoogleFonts.sora(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: const Color(0xFF5B6B8A)))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _filterYear = tempYear; _filterMonth = tempMonth; _filterActive = true; _filterType = tempType;
                                  SocietyData.refreshPayments();
                                });
                                _filterOverlay?.remove(); _filterOverlay = null;
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [Color(0xFF003D99), Color(0xFF0052CC)]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(child: Text('Apply Filter', style: GoogleFonts.sora(
                                    fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );

    Overlay.of(context).insert(_filterOverlay!);
  }

  // ── HOUSES TAB ──────────────────────────────────────────
  Widget _buildHousesTab() {
    final today = _todayPayments;
    return Column(children: [
      if (today.isNotEmpty) _buildTodayActivity(today),
      Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        // Show spinner only on very first load
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)));
        }
        Map<String, Map<String, dynamic>> paymentMap = {};
        if (snap.hasData) {
          for (var doc in snap.data!.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            final house = (data['house'] ?? '').toString().toUpperCase().trim();
            if (house.isNotEmpty) paymentMap[house] = data;
          }
        }

        // Apply search filter
        var houses = SocietyData.allHouses.where((h) =>
            h.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

        // Apply month/year filter
        if (_filterActive && _filterYear != null && _filterMonth != null) {
          final paidHouses = <String>[];
          final unpaidHouses = <String>[];
          for (final house in houses) {
            // Check payments collection (allPayments)
            final paidInPayments = SocietyData.allPayments.any((p) =>
                p['house'].toString().toUpperCase() == house.toUpperCase() &&
                p['month'] == _filterMonth &&
                p['year']  == _filterYear);
            // Check duesByYear in users collection (old data)
            final userData = paymentMap[house.toUpperCase()] ?? {};
            final rawDues = userData['duesByYear'];
            final duesByYear = rawDues == null ? <String, dynamic>{} :
                Map<String, dynamic>.from(
                    (rawDues as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)));
            final rawYear = duesByYear[_filterYear!];
            final yearData = rawYear == null ? <String, dynamic>{} :
                Map<String, dynamic>.from(
                    (rawYear as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)));
            final paidInOldData = yearData[_filterMonth!] == true;

            if (paidInPayments || paidInOldData) {
              paidHouses.add(house);
            } else {
              unpaidHouses.add(house);
            }
          }
          final showPaid = _filterType == 'paid';
          final displayList = showPaid ? paidHouses : unpaidHouses;
          final headerColor = showPaid ? const Color(0xFF06D6A0) : const Color(0xFFEF233C);
          final headerTitle = showPaid
              ? '✅ Paid — $_filterMonth $_filterYear'
              : '❌ Unpaid — $_filterMonth $_filterYear';

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  _FilterStatChip(label: '✅ Paid', count: paidHouses.length, color: const Color(0xFF06D6A0)),
                  const SizedBox(width: 8),
                  _FilterStatChip(label: '❌ Unpaid', count: unpaidHouses.length, color: const Color(0xFFEF233C)),
                ]),
              ),
              if (displayList.isNotEmpty) ...[
                _SectionHeader(title: headerTitle, color: headerColor),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
                  itemCount: displayList.length,
                  itemBuilder: (_, i) => _buildHouseCard(displayList[i], paymentMap[displayList[i].toUpperCase()] ?? {}),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: Text(
                    showPaid ? 'No houses paid for $_filterMonth $_filterYear'
                             : 'All houses paid! 🎉',
                    style: GoogleFonts.sora(color: const Color(0xFF99A8BF), fontSize: 13),
                    textAlign: TextAlign.center,
                  )),
                ),
            ],
          );
        }

        // Normal grid (no filter)
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: houses.length,
          itemBuilder: (context, i) {
            final house = houses[i];
            return _buildHouseCard(house, paymentMap[house.toUpperCase()] ?? {});
          },
        );
      },
    )),
    ]);
  }

  Widget _buildTodayActivity(List<Map<String, dynamic>> today) {
    final visible = today.take(3).toList();
    final extra = today.length - visible.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EAF5)),
        boxShadow: [BoxShadow(color: const Color(0xFF0052CC).withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF003D99), Color(0xFF0052CC)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text("Today's Activity", style: GoogleFonts.sora(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${today.length} entries', style: GoogleFonts.sora(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, -0.15), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(visible.map((e) =>
                (e['timestamp']?.toString() ?? '')).join('|')),
            children: [
              ...visible.map((log) {
                final house  = (log['house']  ?? '').toString();
                final action = (log['action'] ?? '').toString();
                final detail = (log['detail'] ?? '').toString();
                final ts     = log['timestamp'];
                String timeStr = '';
                try {
                  final dt = (ts as dynamic).toDate() as DateTime;
                  timeStr = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
                } catch (_) {}
                Color aColor;
                IconData aIcon;
                if (action.contains('Add')) {
                  aColor = const Color(0xFF06D6A0); aIcon = Icons.add_circle_rounded;
                } else if (action.contains('Delete')) {
                  aColor = const Color(0xFFEF233C); aIcon = Icons.delete_rounded;
                } else {
                  aColor = const Color(0xFFFFAB00); aIcon = Icons.edit_rounded;
                }
                return GestureDetector(
                  onTap: house.isNotEmpty ? () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HouseDetailScreen(houseId: house))) : null,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: const BoxDecoration(border: Border(
                        bottom: BorderSide(color: Color(0xFFE4EAF5), width: 1))),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                          decoration: BoxDecoration(color: aColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(aIcon, color: aColor, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('House # $house', style: GoogleFonts.sora(
                              fontWeight: FontWeight.w800, fontSize: 13,
                              color: const Color(0xFF0A1628))),
                          const SizedBox(width: 6),
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: aColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(action, style: GoogleFonts.sora(
                                  fontSize: 9, fontWeight: FontWeight.w700, color: aColor))),
                        ]),
                        if (detail.isNotEmpty)
                          Text(detail, style: GoogleFonts.sora(
                              fontSize: 11, color: const Color(0xFF99A8BF)),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(timeStr, style: GoogleFonts.sora(fontSize: 11,
                            fontWeight: FontWeight.w700, color: const Color(0xFF99A8BF))),
                        const SizedBox(height: 2),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 11, color: Color(0xFF99A8BF)),
                      ]),
                    ]),
                  ),
                );
              }),
              if (extra > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text('+$extra more today',
                        style: GoogleFonts.sora(
                            fontSize: 11,
                            color: const Color(0xFF0052CC),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildHouseCard(String house, Map<String, dynamic> userData) {
    final now = DateTime.now();
    const totalMonthsTracked = 12; // Full year
    const monthNames = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    int paidMonths = 0;
    for (int m = 1; m <= 12; m++) {
      if (SocietyData.isMonthPaid(house, monthNames[m - 1], now.year.toString())) paidMonths++;
    }

    // Color based on percentage
    final ratio = paidMonths / totalMonthsTracked;
    Color ringColor;
    if (ratio >= 1.0) {
      ringColor = const Color(0xFF36B37E);
    } else if (ratio >= 0.5) {
      ringColor = const Color(0xFFFFAB00);
    } else {
      ringColor = const Color(0xFFFF5630);
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HouseDetailScreen(houseId: house)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ring with house icon
            SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: paidMonths / totalMonthsTracked,
                  color: ringColor,
                ),
                child: Center(
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0052CC).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: Text('🏠', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '# $house',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: const Color(0xFF172B4D),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$paidMonths/$totalMonthsTracked paid',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: ringColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SEND UPDATE NOTIFICATION DIALOG ─────────────────────
  void _showSendNotificationDialog() async {
    // Firebase se current version info lo
    String version = '';
    String releaseNotes = '';
    try {
      final snap = await FirebaseDatabase.instance.ref('app_version').get();
      if (snap.exists) {
        final d = Map<String, dynamic>.from(snap.value as Map);
        version      = d['version']?.toString()       ?? '';
        releaseNotes = d['release_notes']?.toString() ?? '';
      }
    } catch (_) {}

    final savedKey = await UpdateService.getSavedServerKey();
    final keyCtrl  = TextEditingController(text: savedKey);
    bool sending   = false;
    String? result;

    if (!mounted) return;
    showDialog(
      context: context,
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
              child: const Icon(Icons.campaign_rounded,
                  color: Color(0xFF0052CC), size: 26),
            ),
            const SizedBox(height: 10),
            Text('Send Update Notification',
                style: GoogleFonts.sora(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Sab users ko notification jayegi',
                style: GoogleFonts.sora(
                    fontSize: 11, color: Colors.grey)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (version.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF36B37E).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFF36B37E)),
                  const SizedBox(width: 6),
                  Text('Version: v$version',
                      style: GoogleFonts.sora(
                          fontSize: 11, color: const Color(0xFF36B37E),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'FCM Server Key',
                hintText: 'AAAA....:APA91b...',
                helperText:
                    'Firebase Console → Project Settings → Cloud Messaging',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.key_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              style: GoogleFonts.sora(fontSize: 12),
            ),
            if (result != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: result!.startsWith('✅')
                      ? const Color(0xFF36B37E).withOpacity(0.08)
                      : Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(result!,
                    style: GoogleFonts.sora(
                        fontSize: 12,
                        color: result!.startsWith('✅')
                            ? const Color(0xFF36B37E)
                            : Colors.red)),
              ),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.sora(color: Colors.grey))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052CC)),
              onPressed: sending
                  ? null
                  : () async {
                      final key = keyCtrl.text.trim();
                      if (key.isEmpty) {
                        setS(() => result = '❌ Server Key daalo pehle');
                        return;
                      }
                      setS(() { sending = true; result = null; });
                      await UpdateService.saveServerKey(key);
                      final ok =
                          await UpdateService.sendUpdatePushNotification(
                        serverKey: key,
                        version: version,
                        releaseNotes: releaseNotes,
                      );
                      setS(() {
                        sending = false;
                        result  = ok
                            ? '✅ Notification bhjaj di gayi!'
                            : '❌ Failed — Server Key check karo';
                      });
                    },
              icon: sending
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(sending ? 'Sending...' : 'Send',
                  style: GoogleFonts.sora(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  // ── CHANGE PASSWORD DIALOG ───────────────────────────────
  void _showChangePasswordDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Password', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'New password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('admin')
                    .doc('credentials')
                    .set({'password': ctrl.text.trim()}, SetOptions(merge: true));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated!')),
                );
              }
            },
            child: Text('Save', style: GoogleFonts.sora(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── RING PAINTER ─────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 8) / 2;
    const strokeW = 5.0;

    // Background ring
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = color.withOpacity(0.15),
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -3.14159 / 2,
        2 * 3.14159 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}


// ── Filter Stat Chip ────────────────────────────────────────────────────────
class _FilterStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _FilterStatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700,
              color: color)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text('$count', style: GoogleFonts.sora(fontSize: 11,
                fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(title, style: GoogleFonts.sora(
          fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
