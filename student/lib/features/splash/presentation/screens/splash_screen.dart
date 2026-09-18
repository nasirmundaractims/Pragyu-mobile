import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/constants/app_constants.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';

/// S-01 Splash — native Flutter UI matching the reference + session handoff.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _bgTop = Color(0xFFF7FAFE);
  static const _bgMid = Color(0xFFF2F6FC);
  static const _bgBottom = Color(0xFFE8EEF8);
  static const _ink = Color(0xFF1A2B56);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF4A7DFF);
  static const _spinnerBlue = Color(0xFF4A7DFF);
  static const _spinnerPurple = Color(0xFF7C5CFF);
  static const _script = Color(0xFF8EB6E8);

  late final AnimationController _enterController;
  late final AnimationController _spinController;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _fade = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    _enterController.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(AppConstants.splashMinDuration);

    var nextRoute = AppRoutes.welcome;
    try {
      nextRoute = await AuthNavigation.resolveEntryRoute().timeout(
        const Duration(milliseconds: 400),
        onTimeout: () => AppRoutes.welcome,
      );
    } catch (_) {
      nextRoute = AppRoutes.welcome;
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
    final bottomPad = media.padding.bottom;
    final compact = size.height < 720 || size.width < 360;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bgTop, _bgMid, _bgBottom],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
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
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 22,
                      compact ? 8 : 12,
                      compact ? 16 : 22,
                      0,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: size.width < 600 ? 440 : 480,
                              ),
                              child: _SplashContent(
                                compact: compact,
                                ink: _ink,
                                muted: _muted,
                                blue: _blue,
                                script: _script,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: (compact ? 118.0 : 132.0) + bottomPad),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomPad + (compact ? 12 : 18),
              child: FadeTransition(
                opacity: _fade,
                child: _SplashLoadingFooter(
                  spinController: _spinController,
                  muted: _muted,
                  spinnerBlue: _spinnerBlue,
                  spinnerPurple: _spinnerPurple,
                  compact: compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({
    required this.compact,
    required this.ink,
    required this.muted,
    required this.blue,
    required this.script,
  });

  final bool compact;
  final Color ink;
  final Color muted;
  final Color blue;
  final Color script;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SplashBrandHeader(
          compact: compact,
          ink: ink,
          muted: muted,
          script: script,
        ),
        SizedBox(height: compact ? 10 : 16),
        Expanded(
          child: _SplashHeroScene(
            compact: compact,
            ink: ink,
            muted: muted,
            blue: blue,
            script: script,
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          'Your learning companion for a brighter tomorrow.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: compact ? 12.5 : 13.5,
            fontWeight: FontWeight.w500,
            color: muted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SplashBrandHeader extends StatelessWidget {
  const _SplashBrandHeader({
    required this.compact,
    required this.ink,
    required this.muted,
    required this.script,
  });

  final bool compact;
  final Color ink;
  final Color muted;
  final Color script;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: compact ? 28 : 34,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Text(
                    'Smarter Learning\nBrighter Tomorrow',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w500,
                      color: script.withValues(alpha: 0.75),
                      height: 1.15,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 2,
                child: Transform.rotate(
                  angle: 0.1,
                  child: Text(
                    'Learn Practice Grow',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: script.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Image.asset(
          'assets/images/brand/pragyu-mark.png',
          height: compact ? 44 : 52,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Pragyu',
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.eco_rounded,
            size: compact ? 44 : 52,
            color: const Color(0xFF4A7DFF),
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          'Pragyu',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: compact ? 28 : 32,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Learn • Practice • Grow',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: compact ? 12.5 : 13.5,
            fontWeight: FontWeight.w600,
            color: muted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _SplashHeroScene extends StatelessWidget {
  const _SplashHeroScene({
    required this.compact,
    required this.ink,
    required this.muted,
    required this.blue,
    required this.script,
  });

  final bool compact;
  final Color ink;
  final Color muted;
  final Color blue;
  final Color script;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final bookW = compact ? 118.0 : 132.0;
        final cardW = compact ? 138.0 : 154.0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: h * 0.08,
              child: Transform.rotate(
                angle: -0.18,
                child: SizedBox(
                  width: compact ? 72 : 88,
                  child: Text(
                    'Any Learner\nAny Subject\nAny Institution\nA Brighter You',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: script.withValues(alpha: 0.7),
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Image.asset(
                'assets/images/splash/hero_student.png',
                height: h * (compact ? 0.72 : 0.78),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                semanticLabel: 'Student studying at a desk',
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.school_rounded,
                    size: h * 0.28,
                    color: blue,
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              bottom: h * 0.02,
              child: _CategoryBookStack(width: bookW, compact: compact),
            ),
            Positioned(
              right: 0,
              top: h * 0.12,
              child: _FeatureGlassCard(
                width: cardW,
                compact: compact,
                ink: ink,
                muted: muted,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryBookStack extends StatelessWidget {
  const _CategoryBookStack({required this.width, required this.compact});

  final double width;
  final bool compact;

  static const _books = <(Color, IconData, String)>[
    (Color(0xFF1E4FD6), Icons.school_rounded, 'Classes'),
    (Color(0xFF16A34A), Icons.account_balance_rounded, 'Schools'),
    (Color(0xFF7C3AED), Icons.account_balance, 'Colleges & Universities'),
    (Color(0xFFEA580C), Icons.groups_rounded, 'Coaching Institutes'),
    (Color(0xFF0EA5E9), Icons.lightbulb_outline_rounded, 'Lifelong Learning'),
  ];

  @override
  Widget build(BuildContext context) {
    final rowH = compact ? 26.0 : 30.0;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _books.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 3 : 4),
            _BookSpine(
              color: _books[i].$1,
              icon: _books[i].$2,
              label: _books[i].$3,
              height: rowH,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _BookSpine extends StatelessWidget {
  const _BookSpine({
    required this.color,
    required this.icon,
    required this.label,
    required this.height,
    required this.compact,
  });

  final Color color;
  final IconData icon;
  final String label;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: compact ? 13 : 14, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: compact ? 9.5 : 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGlassCard extends StatelessWidget {
  const _FeatureGlassCard({
    required this.width,
    required this.compact,
    required this.ink,
    required this.muted,
  });

  final double width;
  final bool compact;
  final Color ink;
  final Color muted;

  static const _items = <(IconData, Color, String, String)>[
    (
      Icons.school_rounded,
      Color(0xFF3B82F6),
      'Learn',
      'Access quality content',
    ),
    (
      Icons.track_changes_rounded,
      Color(0xFFEC4899),
      'Practice',
      'Sharpen your skills',
    ),
    (
      Icons.bar_chart_rounded,
      Color(0xFF14B8A6),
      'Track Progress',
      'See your growth',
    ),
    (
      Icons.star_rounded,
      Color(0xFFF59E0B),
      'Achieve More',
      'Unlock your potential',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2B56).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 8 : 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 22 : 24,
                  height: compact ? 22 : 24,
                  decoration: BoxDecoration(
                    color: _items[i].$2.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    _items[i].$1,
                    size: compact ? 13 : 14,
                    color: _items[i].$2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _items[i].$3,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: compact ? 10.5 : 11.5,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      Text(
                        _items[i].$4,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: compact ? 8.5 : 9.5,
                          fontWeight: FontWeight.w400,
                          color: muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SplashLoadingFooter extends StatelessWidget {
  const _SplashLoadingFooter({
    required this.spinController,
    required this.muted,
    required this.spinnerBlue,
    required this.spinnerPurple,
    required this.compact,
  });

  final AnimationController spinController;
  final Color muted;
  final Color spinnerBlue;
  final Color spinnerPurple;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spinnerSize = compact ? 32.0 : 36.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: spinnerSize,
          height: spinnerSize,
          child: AnimatedBuilder(
            animation: spinController,
            builder: (context, _) {
              return CustomPaint(
                painter: _GradientSpinnerPainter(
                  progress: spinController.value,
                  blue: spinnerBlue,
                  purple: spinnerPurple,
                ),
              );
            },
          ),
        ),
        SizedBox(height: compact ? 10 : 14),
        Text(
          'Loading your learning journey...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: muted,
            height: 1.35,
          ),
        ),
        SizedBox(height: compact ? 14 : 18),
        Row(
          children: [
            Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'BUILT FOR BRIGHTER FUTURES',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: muted.withValues(alpha: 0.8),
                ),
              ),
            ),
            Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
          ],
        ),
      ],
    );
  }
}

class _SplashWavePainter extends CustomPainter {
  const _SplashWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = Path()
      ..moveTo(0, size.height * 0.08)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.02,
        size.width * 0.5,
        size.height * 0.09,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.16,
        size.width,
        size.height * 0.07,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final bottom = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.7,
        size.width * 0.55,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.9,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      top,
      Paint()..color = const Color(0xFFB8D4F5).withValues(alpha: 0.28),
    );
    canvas.drawPath(
      bottom,
      Paint()..color = const Color(0xFFC9B8F5).withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GradientSpinnerPainter extends CustomPainter {
  const _GradientSpinnerPainter({
    required this.progress,
    required this.blue,
    required this.purple,
  });

  final double progress;
  final Color blue;
  final Color purple;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [blue, purple, blue],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      progress * math.pi * 2,
      math.pi * 1.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
