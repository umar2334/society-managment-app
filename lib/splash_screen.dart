// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  static const Color _pkGreen = Color(0xFF01411C); // Pakistan flag green
  static const Color _pkRed   = Color(0xFFCC0000); // Left stripe red
  static const Color _white   = Colors.white;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5)));
    _ctrl.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _pkGreen,
      body: Stack(children: [

        // ── Green main background ─────────────────────────────────────
        Positioned.fill(
          child: Container(color: _pkGreen),
        ),

        // ── Diagonal stripes (subtle texture) ────────────────────────
        Positioned.fill(
          child: CustomPaint(painter: _FlagDiagonalPainter()),
        ),

        // ── Red left stripe ───────────────────────────────────────────
        Positioned(
          left: 0, top: 0, bottom: 0,
          width: size.width * 0.27,
          child: Container(color: _pkRed),
        ),

        // ── Subtle crescent hint (top right, white) ───────────────────
        Positioned(
          right: size.width * 0.06,
          top: size.height * 0.07,
          child: Opacity(
            opacity: 0.07,
            child: Container(
              width: 200, height: 200,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: _white),
            ),
          ),
        ),
        Positioned(
          right: size.width * 0.02,
          top: size.height * 0.055,
          child: Opacity(
            opacity: 0.07,
            child: Container(
              width: 155, height: 155,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _pkGreen),
            ),
          ),
        ),

        // ── Main Content (white) ──────────────────────────────────────
        SafeArea(
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    // Icon box — white border, white icon
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: _white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: _white.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 12)),
                        ],
                      ),
                      child: const Icon(Icons.apartment_rounded,
                          size: 58, color: _white),  // ← WHITE icon
                    ),
                    const SizedBox(height: 32),

                    // Title — WHITE
                    Text('KARIM NAGAR',
                        style: GoogleFonts.sora(
                          color: _white,               // ← WHITE
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
                        )),
                    const SizedBox(height: 8),

                    // Subtitle — WHITE (semi)
                    Text('SOCIETY MANAGEMENT PORTAL',
                        style: GoogleFonts.sora(
                          color: _white.withOpacity(0.75), // ← WHITE
                          fontSize: 11,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 64),

                    // Progress bar — WHITE
                    Container(
                      width: 140, height: 3,
                      decoration: BoxDecoration(
                        color: _white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 2800),
                        builder: (_, v, __) => FractionallySizedBox(
                          widthFactor: v,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _white,           // ← WHITE bar
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Loading text — WHITE
                    Text('Loading...', style: GoogleFonts.sora(
                        color: _white.withOpacity(0.55), // ← WHITE
                        fontSize: 11, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Diagonal stripes painter ──────────────────────────────────────────────
class _FlagDiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 45
      ..style = PaintingStyle.stroke;

    for (double offset = -200; offset < size.width + 200; offset += 80) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
