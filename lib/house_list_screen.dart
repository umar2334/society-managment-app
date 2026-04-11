// lib/screens/house_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'society_data.dart';
import 'house_detail_screen.dart';

class HouseListScreen extends StatefulWidget {
  const HouseListScreen({super.key});

  @override
  State<HouseListScreen> createState() => _HouseListScreenState();
}

class _HouseListScreenState extends State<HouseListScreen> {
  String _query = '';

  List<String> get filtered => SocietyData.allHouses
      .where((h) => h.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('House Records'),
        backgroundColor: AppTheme.brandDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.brandDark,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: GoogleFonts.sora(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search house number...',
                hintStyle: GoogleFonts.sora(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                fillColor: Colors.white.withOpacity(0.13),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Colors.white30)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Text('${filtered.length} houses', style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textMuted)),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _HouseCard(houseId: filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseCard extends StatefulWidget {
  final String houseId;
  const _HouseCard({required this.houseId});

  @override
  State<_HouseCard> createState() => _HouseCardState();
}

class _HouseCardState extends State<_HouseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    Future.delayed(
      Duration(milliseconds: 60 * (SocietyData.allHouses.indexOf(widget.houseId) % 20)),
      () { if (mounted) _ctrl.forward(); }
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  int _paidMonthsCount() {
    int paid = 0;
    final now = DateTime.now();
    for (int y = 2025; y <= now.year; y++) {
      final dues = SocietyData.getDuesMonths(widget.houseId, y.toString());
      // Total months in year up to now minus dues = paid
      final totalMonths = y < now.year ? 12 : now.month;
      paid += totalMonths - dues.length;
    }
    return paid.clamp(0, 12);
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _paidMonthsCount();
    final progress = paidCount / 12.0;
    final ringColor = paidCount == 12
        ? AppTheme.success
        : paidCount >= 6
            ? AppTheme.gold
            : AppTheme.danger;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, a, __) => HouseDetailScreen(houseId: widget.houseId),
              transitionsBuilder: (_, a, __, child) => FadeTransition(
                opacity: a, child: SlideTransition(
                  position: Tween(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                  child: child)),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [BoxShadow(
                  color: AppTheme.brand.withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Ring + icon
                Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 58, height: 58,
                    child: CustomPaint(
                      painter: _MiniRingPainter(
                        progress: progress,
                        bgColor: ringColor.withOpacity(0.12),
                        fgColor: ringColor,
                      ),
                    ),
                  ),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home_work_rounded,
                        color: AppTheme.brand, size: 22),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('# ${widget.houseId}',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('$paidCount/12 paid',
                    style: GoogleFonts.sora(
                        fontSize: 10,
                        color: ringColor,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color bgColor, fgColor;
  const _MiniRingPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final radius = (size.width - 6) / 2;

    canvas.drawCircle(Offset(cx, cy), radius,
        Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = 5);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -3.14159265358979 / 2,
        2 * 3.14159265358979 * progress,
        false,
        Paint()
          ..color = fgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) => old.progress != progress;
}
