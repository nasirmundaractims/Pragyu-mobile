import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';

/// S-02 Welcome — marketing entry matching Pragyu welcome design.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _ink = Color(0xFF1A2340);
  static const _muted = Color(0xFF6B7385);
  static const _blue = Color(0xFF4A6CF7);
  static const _blueDeep = Color(0xFF7B61FF);
  static const _softBlue = Color(0xFFE8F0FF);
  static const _cardBorder = Color(0xFFEEF1F6);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    AuthNavigation.redirectIfAuthenticated(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goSignIn() {
    Navigator.of(context).pushNamed(AppRoutes.signIn);
  }

  void _goGetStarted() {
    Navigator.of(context).pushNamed(AppRoutes.createAccountStub);
  }

  @override
  Widget build(BuildContext context) {
    final appName = AppConfig.instance.appName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 780;
                  final wide = constraints.maxWidth >= 720;
                  final contentWidth = wide ? 430.0 : constraints.maxWidth;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 24 : 22,
                        8,
                        wide ? 24 : 22,
                        18,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 26,
                          maxWidth: contentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TopBar(appName: appName, onSkip: _goSignIn),
                            SizedBox(height: compact ? 18 : 26),
                            const _Headline(),
                            SizedBox(height: compact ? 8 : 12),
                            _HeroScene(compact: compact),
                            SizedBox(height: compact ? 12 : 16),
                            const _FeatureGrid(),
                            const SizedBox(height: 18),
                            const _PageDots(activeIndex: 0, count: 4),
                            SizedBox(height: compact ? 16 : 20),
                            _GradientCta(
                              label: 'Get Started',
                              onPressed: _goGetStarted,
                            ),
                            const SizedBox(height: 12),
                            _OutlineCta(
                              label: 'I already have an account',
                              onPressed: _goSignIn,
                            ),
                            SizedBox(height: compact ? 18 : 22),
                            const _AudienceRow(),
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
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.appName, required this.onSkip});

  final String appName;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PragyuLogo(height: 40),
              const SizedBox(height: 8),
              const Text(
                'LEARN  ·  PRACTICE  ·  IMPROVE  ·  SUCCEED',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9AA3B5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onSkip,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8A93A8),
            side: const BorderSide(color: Color(0xFFD8DEE9)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: _WelcomeScreenState._ink,
              letterSpacing: -0.35,
            ),
            children: [
              TextSpan(text: 'Your Learning Journey, '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _GradientText(
                  'Smarter',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          'AI-powered learning for students, teachers, and institutes — clearer goals, better results.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14.5,
            height: 1.45,
            color: _WelcomeScreenState._muted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _HeroScene extends StatelessWidget {
  const _HeroScene({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 320.0 : 390.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            right: 8,
            top: height * 0.08,
            bottom: height * 0.04,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _WelcomeScreenState._softBlue.withValues(alpha: 0.9),
                    const Color(0xFFF3EEFF).withValues(alpha: 0.45),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Image.asset(
            'assets/images/welcome_hero.jpg',
            height: height,
            width: double.infinity,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, error, stackTrace) => Icon(
              Icons.school_rounded,
              size: height * 0.35,
              color: _WelcomeScreenState._blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.menu_book_rounded,
        Color(0xFF4A6CF7),
        'Practice & Tests',
        'Prepare better every day',
      ),
      (
        Icons.bar_chart_rounded,
        Color(0xFF14B8A6),
        'Track Progress',
        'See your growth clearly',
      ),
      (
        Icons.psychology_alt_rounded,
        Color(0xFF8B5CF6),
        'AI Evaluation',
        'Get detailed feedback',
      ),
      (
        Icons.school_rounded,
        Color(0xFFF59E0B),
        'Quality Content',
        'Built for competitive exams',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: _FeatureCard(
                  icon: item.$1,
                  iconColor: item.$2,
                  title: item.$3,
                  subtitle: item.$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _WelcomeScreenState._cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2340).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: _WelcomeScreenState._ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    height: 1.3,
                    color: _WelcomeScreenState._muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.activeIndex, required this.count});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: active ? 8 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? _WelcomeScreenState._blue
                : const Color(0xFFD5DBE8),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _GradientCta extends StatelessWidget {
  const _GradientCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                _WelcomeScreenState._blue,
                _WelcomeScreenState._blueDeep,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _WelcomeScreenState._blue.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineCta extends StatelessWidget {
  const _OutlineCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _WelcomeScreenState._blue,
          side: const BorderSide(
            color: _WelcomeScreenState._blue,
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _AudienceRow extends StatelessWidget {
  const _AudienceRow();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF9AA3B5)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9AA3B5),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        item(Icons.school_outlined, 'Students'),
        Container(width: 1, height: 28, color: const Color(0xFFE2E6EF)),
        item(Icons.groups_outlined, 'Teachers'),
        Container(width: 1, height: 28, color: const Color(0xFFE2E6EF)),
        item(Icons.account_balance_outlined, 'Institutes'),
      ],
    );
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          _WelcomeScreenState._blue,
          _WelcomeScreenState._blueDeep,
        ],
      ).createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
