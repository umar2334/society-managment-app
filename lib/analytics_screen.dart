// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'society_data.dart';
import 'house_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _year = DateTime.now().year;
  bool _showMonthlyTotal = false;

  static const _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
  static const _fullNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  @override
  Widget build(BuildContext context) {
    final now         = DateTime.now();
    final total       = SocietyData.calculateTotal();
    final totalHouses = SocietyData.allHouses.length;
    final paidHouses  = SocietyData.houseHistory.values.where((h) => h.isNotEmpty).length;
    final pct         = totalHouses > 0 ? (paidHouses / totalHouses * 100).toStringAsFixed(1) : '0.0';

    // ── Date-based monthly values ──
    // Yahan payment ki DATE ka month use hoga
    // Agar March mein aake Jan+Feb+March diye → March ki bar mein dikhega
    final values = List.generate(12, (i) =>
      SocietyData.getCollectedInCalendarMonth(i + 1, _year));
    final maxVal = values.fold(0.0, (a, b) => b > a ? b : a);
    final yearTotal = values.fold(0.0, (a, b) => a + b);

    // Current month (1-based), only highlight if current year
    final highlightMonth = _year == now.year ? now.month - 1 : -1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppTheme.brandDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Hero ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF003D99), Color(0xFF0052CC), Color(0xFF2684FF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Stack(children: [
              Positioned(right: -20, bottom: -20,
                child: Container(width: 140, height: 140,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.07), width: 35)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Year selector row
                  Row(children: [
                    GestureDetector(
                      onTap: () => setState(() => _year--),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2))),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('$_year',
                        style: GoogleFonts.sora(color: Colors.white,
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => setState(() => _year++),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2))),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text('Analytics', style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text('Total Collection', style: GoogleFonts.sora(
                      color: Colors.white.withOpacity(0.65), fontSize: 12, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('Rs. ${yearTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(color: Colors.white, fontSize: 34,
                          fontWeight: FontWeight.w800, height: 1)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$paidHouses / $totalHouses houses paid',
                          style: GoogleFonts.sora(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 18),

          // ── Stat pills ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _StatBox(val: '$paidHouses', lbl: 'Paid Houses', color: AppTheme.success),
              const SizedBox(width: 10),
              _StatBox(val: '${totalHouses - paidHouses}', lbl: 'Pending', color: AppTheme.danger),
              const SizedBox(width: 10),
              _StatBox(val: '$pct%', lbl: 'Collection', color: AppTheme.gold),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Chart card ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [BoxShadow(color: AppTheme.brand.withOpacity(0.07),
                  blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Monthly Collection',
                      style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  Text(
                    'Based on payment received date — $_year',
                    style: GoogleFonts.sora(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ]),
                GestureDetector(
                  onTap: () => setState(() => _showMonthlyTotal = !_showMonthlyTotal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: _showMonthlyTotal
                            ? AppTheme.brand
                            : AppTheme.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        _showMonthlyTotal ? 'Hide Totals' : 'Show Totals',
                        style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700,
                            color: _showMonthlyTotal ? Colors.white : AppTheme.brand)),
                  ),
                ),
              ]),

              // ── Legend ──
              const SizedBox(height: 10),
              Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(
                    color: AppTheme.brand, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('Month payment was received', style: GoogleFonts.sora(
                    fontSize: 9, color: AppTheme.textMuted)),
                const SizedBox(width: 12),
                Container(width: 12, height: 12, decoration: BoxDecoration(
                    color: AppTheme.accent, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('Current month', style: GoogleFonts.sora(
                    fontSize: 9, color: AppTheme.textMuted)),
              ]),

              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(12, (i) {
                    final v        = values[i];
                    final hFactor  = maxVal == 0 ? 0.0 : v / maxVal;
                    final barH     = 150.0 * hFactor;
                    final isCurrent = i == highlightMonth;
                    final barColor = isCurrent ? AppTheme.accent : AppTheme.brand;

                    return Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (v > 0 && _showMonthlyTotal) ...[
                          Text(
                            v >= 1000
                                ? 'Rs.${(v / 1000).toStringAsFixed(1)}k'
                                : 'Rs.${v.toStringAsFixed(0)}',
                            style: GoogleFonts.sora(fontSize: 7,
                                fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 3),
                        ],
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400 + i * 60),
                          curve: Curves.easeOutCubic,
                          width: double.infinity,
                          height: v > 0 ? barH.clamp(6.0, 150.0) : 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: v > 0 ? barColor : AppTheme.divider,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            boxShadow: isCurrent && v > 0
                                ? [BoxShadow(color: AppTheme.accent.withOpacity(0.4),
                                    blurRadius: 8, offset: const Offset(0, -2))]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_monthNames[i],
                            style: GoogleFonts.sora(
                                fontSize: 9, fontWeight: FontWeight.w600,
                                color: isCurrent ? AppTheme.brand : AppTheme.textMuted)),
                        if (isCurrent)
                          Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 2),
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: AppTheme.accent)),
                      ]),
                    );
                  }),
                ),
              ),

              // ── Note ──
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.brand.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.brand.withOpacity(0.12))),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If a payment covers multiple past months,'
                       'the total amount will appear in the bar for the month the payment was actually received. ',
                      
                      style: GoogleFonts.sora(fontSize: 9, color: AppTheme.brand),
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          // ── Per-month breakdown ──
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Month-wise Breakdown $_year',
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 14),
              ...List.generate(12, (i) {
                final v        = values[i];
                final isCurr   = i == highlightMonth;
                if (v == 0 && !isCurr) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: v > 0 ? () => Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (_, a, __) => _MonthPaymentsScreen(
                      month: i + 1, year: _year,
                      monthName: _fullNames[i],
                    ),
                    transitionsBuilder: (_, a, __, child) => SlideTransition(
                      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                      child: child),
                    transitionDuration: const Duration(milliseconds: 300),
                  )) : null,
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurr
                        ? AppTheme.brand.withOpacity(0.06)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isCurr
                            ? AppTheme.brand.withOpacity(0.2)
                            : AppTheme.divider),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: (isCurr ? AppTheme.accent : AppTheme.brand)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text('${i + 1}',
                            style: GoogleFonts.sora(fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isCurr ? AppTheme.accent : AppTheme.brand)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_fullNames[i],
                        style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary))),
                    if (isCurr)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppTheme.brand, borderRadius: BorderRadius.circular(20)),
                        child: Text('CURRENT',
                            style: GoogleFonts.sora(fontSize: 8, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 0.5)),
                      ),
                    if (v > 0)
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(v > 0 ? 'Rs. ${v.toStringAsFixed(0)}' : 'Rs. 0',
                        style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800,
                            color: v > 0 ? AppTheme.brand : AppTheme.textMuted)),
                  ]),
                  ),
                );
              }),
              if (values.every((v) => v == 0))
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Icon(Icons.bar_chart_rounded, size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 10),
                      Text('No payments recorded for $_year',
                          style: GoogleFonts.sora(color: AppTheme.textMuted, fontSize: 12)),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String val, lbl;
  final Color color;
  const _StatBox({required this.val, required this.lbl, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 3),
          Text(lbl, style: GoogleFonts.sora(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Month Payments Screen — us month mein jinon ne payment ki
// ═══════════════════════════════════════════════════════════════════════════
class _MonthPaymentsScreen extends StatelessWidget {
  final int month, year;
  final String monthName;

  const _MonthPaymentsScreen({
    required this.month, required this.year, required this.monthName,
  });

  List<Map<String, dynamic>> _getPayments() {
    final result = <Map<String, dynamic>>[];
    for (final house in SocietyData.allHouses) {
      final history = SocietyData.houseHistory[house] ?? [];
      for (final payment in history) {
        final dateStr = payment['date'] ?? '';
        if (dateStr.isEmpty) continue;
        try {
          final parts = dateStr.split('/');
          if (parts.length != 3) continue;
          final pMonth = int.parse(parts[1]);
          final pYear  = int.parse(parts[2]);
          if (pMonth == month && pYear == year) {
            result.add({
              'house':  house,
              'date':   dateStr,
              'period': payment['period'] ?? '',
              'amount': double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0,
            });
          }
        } catch (_) {}
      }
    }
    // Sort by date
    result.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final payments = _getPayments();
    final total = payments.fold<double>(0, (s, p) => s + (p['amount'] as double));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(children: [
        // ── Header ──
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF003D99), Color(0xFF0052CC), Color(0xFF2684FF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$monthName $year',
                        style: GoogleFonts.sora(color: Colors.white,
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Payment Details',
                        style: GoogleFonts.sora(
                            color: Colors.white.withOpacity(0.65), fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 20),
                // Stats row
                Row(children: [
                  _MStatCard(
                    icon: Icons.home_work_rounded,
                    label: 'Houses Paid',
                    value: '${payments.length}',
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  _MStatCard(
                    icon: Icons.payments_rounded,
                    label: 'Total Collected',
                    value: 'Rs.${total.toStringAsFixed(0)}',
                    color: AppTheme.gold,
                  ),
                ]),
              ]),
            ),
          ),
        ),

        // ── List ──
        Expanded(
          child: payments.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.receipt_long_rounded, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Text('No payments in $monthName $year',
                      style: GoogleFonts.sora(color: AppTheme.textMuted, fontSize: 14)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: payments.length,
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    final house  = p['house'] as String;
                    final date   = p['date'] as String;
                    final period = p['period'] as String;
                    final amount = p['amount'] as double;

                    return GestureDetector(
                      onTap: () => Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (_, a, __) =>
                            HouseDetailScreen(houseId: house, isAdminView: true),
                        transitionsBuilder: (_, a, __, child) => FadeTransition(
                            opacity: a, child: child),
                        transitionDuration: const Duration(milliseconds: 250),
                      )),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                          boxShadow: [BoxShadow(
                              color: AppTheme.brand.withOpacity(0.05),
                              blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(children: [
                          // House icon
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF003D99), Color(0xFF0052CC)]),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(Icons.home_work_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          // Details
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('House # $house',
                                style: GoogleFonts.sora(fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 10, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text('Paid on: $date',
                                  style: GoogleFonts.sora(
                                      fontSize: 11, color: AppTheme.textMuted)),
                            ]),
                            if (period.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.receipt_rounded,
                                    size: 10, color: AppTheme.textMuted),
                                const SizedBox(width: 4),
                                Expanded(child: Text('For: $period',
                                    style: GoogleFonts.sora(
                                        fontSize: 11, color: AppTheme.textMuted),
                                    overflow: TextOverflow.ellipsis)),
                              ]),
                            ],
                          ])),
                          // Amount
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('Rs.${amount.toStringAsFixed(0)}',
                                style: GoogleFonts.sora(
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: AppTheme.brand)),
                            const SizedBox(height: 4),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 12, color: AppTheme.textMuted),
                          ]),
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

class _MStatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _MStatCard({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: GoogleFonts.sora(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            Text(label, style: GoogleFonts.sora(
                color: Colors.white.withOpacity(0.6), fontSize: 9)),
          ])),
        ]),
      ),
    );
  }
}
