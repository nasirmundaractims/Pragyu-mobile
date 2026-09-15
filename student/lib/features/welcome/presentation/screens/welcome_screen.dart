import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/core/config/app_config.dart';

/// S-02 Welcome — marketing entry matching Pragyu welcome design.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF4A7DFF);
  static const _blueDeep = Color(0xFF5B4CFF);
  static const _softBlue = Color(0xFFEAF1FF);
  static const _softLavender = Color(0xFFF3EEFF);

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
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
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
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF7FAFF),
                Colors.white,
                _softLavender,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 740;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        compact ? 8 : 12,
                        22,
                        18,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 30,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _goSignIn,
                                style: TextButton.styleFrom(
                                  foregroundColor: _blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _BrandHeader(appName: appName),
                            SizedBox(height: compact ? 16 : 22),
                            const _Headline(),
                            SizedBox(height: compact ? 12 : 18),
                            _HeroScene(compact: compact),
                            const SizedBox(height: 14),
                            const _PageDots(activeIndex: 0, count: 4),
                            SizedBox(height: compact ? 16 : 22),
                            _GradientCta(
                              label: 'Get Started',
                              onPressed: _goGetStarted,
                            ),
                            const SizedBox(height: 12),
                            _OutlineCta(
                              label: 'I already have an account',
                              onPressed: _goSignIn,
                            ),
                            SizedBox(height: compact ? 18 : 24),
                            const _AudienceRow(),
                            const SizedBox(height: 12),
                            const Text(
                              'Together for a Smarter Future',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA0A8B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PragyuMark(size: 36),
            const SizedBox(width: 10),
            Text(
              appName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _WelcomeScreenState._ink,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Learn  Practice  Improve  Succeed',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w500,
            color: _WelcomeScreenState._muted.withValues(alpha: 0.9),
          ),
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
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: _WelcomeScreenState._ink,
            ),
            children: [
              TextSpan(text: 'Your Learning\nJourney, '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _GradientText(
                  'Smarter',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          'AI-powered learning platform for students,\nteachers and institutes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: _WelcomeScreenState._muted,
            fontWeight: FontWeight.w500,
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
    final height = compact ? 250.0 : 300.0;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.85,
                  colors: [
                    _WelcomeScreenState._softBlue.withValues(alpha: 0.7),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: height * 0.18,
            child: const Text(
              'Dream\nPrepare\nAchieve',
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontStyle: FontStyle.italic,
                color: Color(0xFFB8C0D0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: height * 0.22,
            child: const Text(
              'A Brighter\nYou',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontStyle: FontStyle.italic,
                color: Color(0xFFB8C0D0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: height * 0.02,
            child: const _FeatureChip(
              icon: Icons.checklist_rounded,
              iconColor: Color(0xFF3D7BFF),
              title: 'Practice & Tests',
              subtitle: 'Prepare better',
            ),
          ),
          Positioned(
            right: 0,
            top: height * 0.02,
            child: const _FeatureChip(
              icon: Icons.bar_chart_rounded,
              iconColor: Color(0xFF2EAE6B),
              title: 'Track Progress',
              subtitle: 'See your growth',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Image.asset(
              'assets/images/welcome_hero.jpg',
              height: height * 0.88,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) => Icon(
                Icons.school_rounded,
                size: height * 0.35,
                color: _WelcomeScreenState._blue,
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: height * 0.12,
            child: const _FeatureChip(
              icon: Icons.memory_rounded,
              iconColor: Color(0xFF8B5CF6),
              title: 'AI Evaluation',
              subtitle: 'Get detailed feedback',
            ),
          ),
          Positioned(
            right: 0,
            bottom: height * 0.12,
            child: const _FeatureChip(
              icon: Icons.school_rounded,
              iconColor: Color(0xFFF59E0B),
              title: 'Quality Content',
              subtitle: 'For competitive exams',
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
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
      width: 138,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2B4C).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _WelcomeScreenState._ink,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: _WelcomeScreenState._muted,
                    fontWeight: FontWeight.w500,
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
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 7,
          height: 7,
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
                color: _WelcomeScreenState._blue.withValues(alpha: 0.35),
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
            fontSize: 15,
            fontWeight: FontWeight.w700,
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
            Icon(icon, size: 20, color: _WelcomeScreenState._muted),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _WelcomeScreenState._muted,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        item(Icons.menu_book_rounded, 'Students'),
        Container(width: 1, height: 28, color: const Color(0xFFE2E6EF)),
        item(Icons.groups_rounded, 'Teachers'),
        Container(width: 1, height: 28, color: const Color(0xFFE2E6EF)),
        item(Icons.account_balance_rounded, 'Institutes'),
      ],
    );
  }
}

class _PragyuMark extends StatelessWidget {
  const _PragyuMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 6,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _WelcomeScreenState._blue,
                  Color(0xFF8B5CF6),
                ],
              ).createShader(bounds),
              child: Text(
                'P',
                style: TextStyle(
                  fontSize: size * 0.78,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.02,
            top: -1,
            child: Icon(
              Icons.school_rounded,
              size: size * 0.38,
              color: _WelcomeScreenState._ink,
            ),
          ),
        ],
      ),
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
          Color(0xFF8B5CF6),
        ],
      ).createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
