// lib/dues_list_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'app_theme.dart';
import 'society_data.dart';
import 'house_detail_screen.dart';

class DuesListScreen extends StatefulWidget {
  const DuesListScreen({super.key});

  @override
  State<DuesListScreen> createState() => _DuesListScreenState();
}

class _DuesListScreenState extends State<DuesListScreen>
    with SingleTickerProviderStateMixin {
  bool _downloading = false;
  String _searchQuery = '';
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  List<Map<String, dynamic>> _getDuesList() {
    final now  = DateTime.now();
    final list = <Map<String, dynamic>>[];

    for (final house in SocietyData.allHouses) {
      final duesByYear = <String, List<String>>{};
      int total = 0;
      for (int y = 2025; y <= now.year; y++) {
        final dues = SocietyData.getDuesMonths(house, y.toString());
        if (dues.isNotEmpty) {
          duesByYear[y.toString()] = dues;
          total += dues.length;
        }
      }
      if (total > 0) {
        list.add({
          'house': house,
          'duesByYear': duesByYear,
          'duesCount': total,
          'totalDue': total * SocietyData.monthlyFee,
        });
      }
    }
    list.sort((a, b) => (b['duesCount'] as int).compareTo(a['duesCount'] as int));
    return list;
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final duesList = _getDuesList();
      final now = DateTime.now();
      final year = now.year.toString();

      final pdf = pw.Document();
      final font     = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0052CC),
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('KARIM NAGAR SOCIETY',
                  style: pw.TextStyle(font: fontBold, fontSize: 15,
                      color: PdfColors.white)),
              pw.Text('Pending Dues Report — $year',
                  style: pw.TextStyle(fontSize: 10,
                      color: PdfColor.fromInt(0xFFCCDDFF))),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('${duesList.length} houses',
                  style: pw.TextStyle(font: fontBold, fontSize: 12,
                      color: PdfColors.white)),
              pw.Text('${now.day}/${now.month}/${now.year}',
                  style: pw.TextStyle(fontSize: 9,
                      color: PdfColor.fromInt(0xFFCCDDFF))),
            ]),
          ]),
        ),
        build: (ctx) => [
          if (duesList.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE8FDF5),
                  borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text('No dues found!',
                  style: pw.TextStyle(font: fontBold, fontSize: 13,
                      color: PdfColor.fromInt(0xFF048A6B))),
            )
          else ...[
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE4EAF5), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(4),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF0052CC)),
                  children: [
                    _cell('House', fontBold, isHeader: true),
                    _cell('Months', fontBold, isHeader: true),
                    _cell('Pending', fontBold, isHeader: true),
                    _cell('Amount', fontBold, isHeader: true),
                  ],
                ),
                ...duesList.asMap().entries.map((e) {
                  final i    = e.key;
                  final item = e.value;
                  final bg   = i.isEven
                      ? PdfColor.fromInt(0xFFFFFFFF)
                      : PdfColor.fromInt(0xFFF4F7FF);
                  final duesByYear = item['duesByYear'] as Map<String, dynamic>;
                  final duesStr = duesByYear.entries.map((ye) {
                    final months = (ye.value as List<dynamic>).cast<String>();
                    return '${ye.key}: ${months.map((m) => m.substring(0, 3)).join(', ')}';
                  }).join(' | ');
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _cell(item['house'] as String, fontBold),
                      _cell('${item['duesCount']}', font),
                      _cell(duesStr, font),
                      _cell('Rs. ${(item['totalDue'] as double).toStringAsFixed(0)}', fontBold),
                    ],
                  );
                }),
              ],
            ),
          ],
        ],
      ));

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'KarimNagar_Dues_$year.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF downloaded!',
              style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.sora(color: Colors.white)),
          backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  pw.Widget _cell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Text(text, style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
          color: isHeader ? PdfColors.white : PdfColor.fromInt(0xFF0A1628))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duesList = _getDuesList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Dues List',
            style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: const Color(0xFF003D99),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _downloading ? null : _downloadPdf,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _downloading
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: _downloading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text('PDF', style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          // Summary bar
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF003D99), Color(0xFF0052CC)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${duesList.length}', style: GoogleFonts.sora(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('Houses with dues', style: GoogleFonts.sora(
                          color: Colors.white.withOpacity(0.6), fontSize: 10)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Rs.${duesList.fold<double>(0, (s, e) => s + (e['totalDue'] as double)).toStringAsFixed(0)}',
                          style: GoogleFonts.sora(color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      Text('Total pending', style: GoogleFonts.sora(
                          color: Colors.white.withOpacity(0.6), fontSize: 10)),
                    ])),
                  ]),
                ),
              ),
            ]),
          ),
          // Search bar
          Container(
            color: const Color(0xFF003D99),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.sora(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search house number...',
                hintStyle: GoogleFonts.sora(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() => _searchQuery = ''),
                        child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16))
                    : null,
                fillColor: Colors.white.withOpacity(0.13),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white30)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // List
          Expanded(
            child: () {
              final filtered = _searchQuery.isEmpty
                  ? duesList
                  : duesList.where((item) =>
                      (item['house'] as String).toLowerCase()
                          .contains(_searchQuery.toLowerCase())).toList();
              return filtered.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No house found' : 'No dues! All clear 🎉',
                          style: GoogleFonts.sora(fontSize: 16,
                              fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return _DuesCard(item: item, index: i);
                      },
                    );
            }(),
          ),
        ]),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SummaryChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.sora(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _DuesCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  const _DuesCard({required this.item, required this.index});

  @override
  State<_DuesCard> createState() => _DuesCardState();
}

class _DuesCardState extends State<_DuesCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    Future.delayed(
      Duration(milliseconds: 60 * widget.index),
      () { if (mounted) _ctrl.forward(); }
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final house      = widget.item['house'] as String;
    final duesByYear = widget.item['duesByYear'] as Map<String, List<String>>;
    final duesCount  = widget.item['duesCount'] as int;
    final totalDue   = widget.item['totalDue'] as double;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _slideAnim.value),
        child: Opacity(opacity: _fadeAnim.value, child: child),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, a, __) => HouseDetailScreen(houseId: house),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: a, child: SlideTransition(
              position: Tween(begin: const Offset(0.05, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
              child: child)),
          transitionDuration: const Duration(milliseconds: 300),
        )),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.danger.withOpacity(0.12)),
            boxShadow: [BoxShadow(
                color: AppTheme.danger.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.brand.withOpacity(0.15), AppTheme.brand.withOpacity(0.08)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.home_work_rounded, color: AppTheme.brand, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('# $house', style: GoogleFonts.sora(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$duesCount months', style: GoogleFonts.sora(
                      fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 4, children: duesByYear.entries.map((e) {
                final months = e.value.map((m) => m.substring(0, 3)).join(', ');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Text('${e.key}: $months',
                      style: GoogleFonts.sora(fontSize: 9,
                          color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                );
              }).toList()),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Rs. ${totalDue.toStringAsFixed(0)}',
                  style: GoogleFonts.sora(fontSize: 14,
                      fontWeight: FontWeight.w800, color: AppTheme.danger)),
              const SizedBox(height: 6),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.brand),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
