import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/constants/app_constants.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';

/// S-01 Splash — centered brand logo + tagline + session handoff.
///
/// Uses the same [PragyuLogo] wordmark as the rest of the Student App.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _ink = Color(0xFF1A237E);
  static const _learnBlue = Color(0xFF3D7EFF);
  static const _practiceNavy = Color(0xFF1A2B56);
  static const _growOrange = Color(0xFFFF8A1F);
  static const _footerBlue = Color(0xFF7BA3D4);
  static const _spinnerStart = Color(0xFF9CC4FF);
  static const _spinnerEnd = Color(0xFF3D7EFF);
  static const _waveBlue = Color(0xFF2F6BFF);
  static const _wavePurple = Color(0xFF9B3DFF);
  static const _washBlue = Color(0xFFD9E8FF);
  static const _washPeach = Color(0xFFFFE4D4);
  static const _glyph = Color(0xFFB8C7DE);

  late final AnimationController _enterController;
  late final AnimationController _spinController;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _fade = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    _enterController.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(AppConstants.splashMinDuration);

    var nextRoute = AppRoutes.signIn;
    try {
      nextRoute = await AuthNavigation.resolveEntryRoute().timeout(
        const Duration(milliseconds: 400),
        onTimeout: () => AppRoutes.signIn,
      );
    } catch (_) {
      nextRoute = AppRoutes.signIn;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  @override
  void dispose() {
    _enterController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final short = size.height < 700;
    final narrow = size.width < 360;
    final markMax = (size.shortestSide * (short ? 0.42 : 0.48)).clamp(
      148.0,
      240.0,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.white),
            const CustomPaint(painter: _SplashAmbientPainter()),
            const CustomPaint(painter: _SplashWavePainter()),
            FadeTransition(
              opacity: _fade,
              child: AnimatedBuilder(
                animation: _slide,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slide.value),
                    child: child,
                  );
                },
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: narrow ? 20 : 28,
                              vertical: short ? 12 : 20,
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: short ? 28 : 56),
                                _BrandBlock(markMax: markMax),
                                SizedBox(height: short ? 36 : 52),
                                _GradientSpinner(controller: _spinController),
                                SizedBox(height: short ? 28 : 40),
                                Text(
                                  'Building a Brighter Tomorrow',
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: short ? 13.5 : 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    color: _footerBlue,
                                    height: 1.35,
                                  ),
                                ),
                                SizedBox(height: short ? 48 : 72),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.markMax});

  final double markMax;

  @override
  Widget build(BuildContext context) {
    final logoHeight = (markMax * 0.42).clamp(72.0, 112.0);

    return Semantics(
      label: 'Pragyu. Learn, Practice, Grow.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PragyuLogo(
            height: logoHeight,
            alignment: Alignment.center,
            semanticsLabel: 'Pragyu',
          ),
          const SizedBox(height: 18),
          const _TaglineRow(),
        ],
      ),
    );
  }
}

class _TaglineRow extends StatelessWidget {
  const _TaglineRow();

  @override
  Widget build(BuildContext context) {
    TextStyle word(Color color, {double size = 15.5}) => TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: color,
          height: 1.2,
        );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Learn', style: word(_SplashScreenState._learnBlue)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('•', style: word(_SplashScreenState._learnBlue, size: 14)),
          ),
          Text('Practice', style: word(_SplashScreenState._practiceNavy)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('•', style: word(_SplashScreenState._growOrange, size: 14)),
          ),
          Text('Grow', style: word(_SplashScreenState._growOrange)),
        ],
      ),
    );
  }
}

class _GradientSpinner extends StatelessWidget {
  const _GradientSpinner({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: 44,
        height: 44,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _GradientArcPainter(
                progress: controller.value,
                start: _SplashScreenState._spinnerStart,
                end: _SplashScreenState._spinnerEnd,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GradientArcPainter extends CustomPainter {
  _GradientArcPainter({
    required this.progress,
    required this.start,
    required this.end,
  });

  final double progress;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [start, end, start],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      progress * math.pi * 2,
      math.pi * 1.35,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Soft corner washes + faint educational outline glyphs.
class _SplashAmbientPainter extends CustomPainter {
  const _SplashAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blueWash = Paint()
      ..shader = RadialGradient(
        colors: [
          _SplashScreenState._washBlue.withValues(alpha: 0.55),
          _SplashScreenState._washBlue.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * -0.05, size.height * 0.02),
        radius: size.shortestSide * 0.55,
      ));
    canvas.drawCircle(
      Offset(size.width * -0.05, size.height * 0.02),
      size.shortestSide * 0.55,
      blueWash,
    );

    final peachWash = Paint()
      ..shader = RadialGradient(
        colors: [
          _SplashScreenState._washPeach.withValues(alpha: 0.5),
          _SplashScreenState._washPeach.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 1.05, size.height * 0.08),
        radius: size.shortestSide * 0.48,
      ));
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 0.08),
      size.shortestSide * 0.48,
      peachWash,
    );

    final glyphPaint = Paint()
      ..color = _SplashScreenState._glyph.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawBook(canvas, Offset(size.width * 0.14, size.height * 0.16), 18, glyphPaint);
    _drawCap(canvas, Offset(size.width * 0.82, size.height * 0.18), 16, glyphPaint);
    _drawBulb(canvas, Offset(size.width * 0.12, size.height * 0.42), 14, glyphPaint);
    _drawChart(canvas, Offset(size.width * 0.88, size.height * 0.40), 15, glyphPaint);
    _drawTarget(canvas, Offset(size.width * 0.80, size.height * 0.58), 15, glyphPaint);
  }

  void _drawBook(Canvas canvas, Offset c, double s, Paint p) {
    final path = Path()
      ..moveTo(c.dx - s * 0.55, c.dy - s * 0.35)
      ..quadraticBezierTo(c.dx, c.dy - s * 0.55, c.dx + s * 0.55, c.dy - s * 0.35)
      ..lineTo(c.dx + s * 0.55, c.dy + s * 0.4)
      ..quadraticBezierTo(c.dx, c.dy + s * 0.2, c.dx - s * 0.55, c.dy + s * 0.4)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawLine(
      Offset(c.dx, c.dy - s * 0.45),
      Offset(c.dx, c.dy + s * 0.3),
      p,
    );
  }

  void _drawCap(Canvas canvas, Offset c, double s, Paint p) {
    final top = Path()
      ..moveTo(c.dx, c.dy - s * 0.45)
      ..lineTo(c.dx + s * 0.7, c.dy - s * 0.1)
      ..lineTo(c.dx, c.dy + s * 0.15)
      ..lineTo(c.dx - s * 0.7, c.dy - s * 0.1)
      ..close();
    canvas.drawPath(top, p);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.05), width: s * 0.9, height: s * 0.55),
      0.15,
      math.pi - 0.3,
      false,
      p,
    );
  }

  void _drawBulb(Canvas canvas, Offset c, double s, Paint p) {
    canvas.drawCircle(Offset(c.dx, c.dy - s * 0.1), s * 0.45, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.45), width: s * 0.45, height: s * 0.28),
        const Radius.circular(3),
      ),
      p,
    );
  }

  void _drawChart(Canvas canvas, Offset c, double s, Paint p) {
    canvas.drawLine(Offset(c.dx - s * 0.55, c.dy + s * 0.45), Offset(c.dx - s * 0.55, c.dy - s * 0.1), p);
    canvas.drawLine(Offset(c.dx - s * 0.15, c.dy + s * 0.45), Offset(c.dx - s * 0.15, c.dy - s * 0.35), p);
    canvas.drawLine(Offset(c.dx + s * 0.25, c.dy + s * 0.45), Offset(c.dx + s * 0.25, c.dy - s * 0.55), p);
  }

  void _drawTarget(Canvas canvas, Offset c, double s, Paint p) {
    canvas.drawCircle(c, s * 0.55, p);
    canvas.drawCircle(c, s * 0.3, p);
    canvas.drawCircle(c, s * 0.08, p..style = PaintingStyle.fill);
    p.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom blue / purple wave accents.
class _SplashWavePainter extends CustomPainter {
  const _SplashWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    final soft = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.25, h * 0.80, w * 0.5, h * 0.88)
      ..quadraticBezierTo(w * 0.78, h * 0.96, w, h * 0.90)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      soft,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFB7D2FF).withValues(alpha: 0.45),
            const Color(0xFFD7C4FF).withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.78, w, h * 0.22)),
    );

    final blue = Path()
      ..moveTo(0, h * 0.90)
      ..quadraticBezierTo(w * 0.18, h * 0.82, w * 0.42, h * 0.90)
      ..quadraticBezierTo(w * 0.58, h * 0.96, w * 0.72, h * 0.93)
      ..lineTo(w * 0.72, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      blue,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A8CFF),
            _SplashScreenState._waveBlue,
            Color(0xFF1E4FD6),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.8, w * 0.75, h * 0.2)),
    );

    final purple = Path()
      ..moveTo(w * 0.48, h)
      ..quadraticBezierTo(w * 0.62, h * 0.86, w * 0.82, h * 0.90)
      ..quadraticBezierTo(w * 0.94, h * 0.93, w, h * 0.88)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      purple,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC05CFF),
            _SplashScreenState._wavePurple,
            Color(0xFF6A1B9A),
          ],
        ).createShader(Rect.fromLTWH(w * 0.45, h * 0.82, w * 0.55, h * 0.18)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
