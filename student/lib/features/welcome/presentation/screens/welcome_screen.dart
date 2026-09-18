import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';

/// S-02 Welcome / onboarding — responsive native UI matching the reference.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _ink = Color(0xFF0D2052);
  static const _muted = Color(0xFF6B7280);
  static const _blue = Color(0xFF0055FF);
  static const _blueDeep = Color(0xFF0040CC);
  static const _dotInactive = Color(0xFFD4DFF5);
  static const _skip = Color(0xFF9AA3B5);
  static const _bg = Color(0xFFF7F9FC);

  static const _pageCount = 3;

  PageController? _pageController;
  int _pageIndex = 0;

  PageController get _pages => _pageController ??= PageController();

  bool get _isFirst => _pageIndex == 0;
  bool get _isLast => _pageIndex >= _pageCount - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    AuthNavigation.redirectIfAuthenticated(context);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _pageController = null;
    super.dispose();
  }

  void _goSignIn() {
    Navigator.of(context).pushNamed(AppRoutes.signIn);
  }

  void _goGetStarted() {
    Navigator.of(context).pushNamed(AppRoutes.createAccountStub);
  }

  void _next() {
    if (_isLast) {
      _goGetStarted();
      return;
    }
    if (!_pages.hasClients) return;
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_isFirst || !_pages.hasClients) return;
    _pages.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pageCount) return;
    if (!_pages.hasClients) return;
    if (index == _pageIndex) return;
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final short = size.height < 700;
    final narrow = size.width < 360;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW =
                  constraints.maxWidth >= 720 ? 440.0 : constraints.maxWidth;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxW,
                    maxHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _pages,
                          physics: const BouncingScrollPhysics(
                            parent: PageScrollPhysics(),
                          ),
                          onPageChanged: (i) => setState(() => _pageIndex = i),
                          children: [
                            _OnboardingPage(
                              short: short,
                              narrow: narrow,
                              ink: _ink,
                              muted: _muted,
                              blue: _blue,
                              skip: _skip,
                              onSkip: _goSignIn,
                              header: const _BrandHeader(),
                              title: const [
                                _TitlePart('Your Preparation\n', false),
                                _TitlePart('Companion', true),
                              ],
                              body:
                                  'Quality content, smart practice and AI-powered feedback — all in one place.',
                              blob: const Color(0xFFC8DDFF),
                              heroAsset:
                                  'assets/images/onboarding/hero_companion.png',
                              heroLabel: 'Student holding a notebook',
                            ),
                            _OnboardingPage(
                              short: short,
                              narrow: narrow,
                              ink: _ink,
                              muted: _muted,
                              blue: _blue,
                              skip: _skip,
                              onSkip: _goSignIn,
                              header: const _AccentIcon(
                                background: Color(0xFFFFE4EF),
                                iconColor: Color(0xFFE91E8C),
                                icon: Icons.track_changes_rounded,
                              ),
                              title: const [
                                _TitlePart('Practice with\n', false),
                                _TitlePart('Purpose', true),
                              ],
                              body:
                                  'Take quizzes, mock tests, previous year papers and get instant AI-powered feedback.',
                              blob: const Color(0xFFE0D4FF),
                              heroAsset:
                                  'assets/images/onboarding/hero_practice.png',
                              heroLabel: 'Student practicing on a laptop',
                              chips: true,
                            ),
                            _OnboardingPage(
                              short: short,
                              narrow: narrow,
                              ink: _ink,
                              muted: _muted,
                              blue: _blue,
                              skip: _skip,
                              onSkip: _goSignIn,
                              header: const _AccentIcon(
                                background: Color(0xFFDDF7E8),
                                iconColor: Color(0xFF12B76A),
                                icon: Icons.bar_chart_rounded,
                              ),
                              title: const [
                                _TitlePart('Track Your\n', false),
                                _TitlePart('Growth', true),
                              ],
                              body:
                                  'Stay consistent, track your progress and get closer to your dream.',
                              blob: const Color(0xFFC8F0D8),
                              heroAsset:
                                  'assets/images/onboarding/hero_growth.png',
                              heroLabel:
                                  'Student celebrating learning progress',
                            ),
                          ],
                        ),
                      ),
                      _BottomChrome(
                        index: _pageIndex,
                        pageCount: _pageCount,
                        isFirst: _isFirst,
                        isLast: _isLast,
                        short: short,
                        muted: _muted,
                        blue: _blue,
                        blueDeep: _blueDeep,
                        dotInactive: _dotInactive,
                        onBack: _back,
                        onNext: _next,
                        onGetStarted: _goGetStarted,
                        onSignIn: _goSignIn,
                        onDotTap: _goToPage,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class _TitlePart {
  const _TitlePart(this.text, this.accent);
  final String text;
  final bool accent;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.short,
    required this.narrow,
    required this.ink,
    required this.muted,
    required this.blue,
    required this.skip,
    required this.onSkip,
    required this.header,
    required this.title,
    required this.body,
    required this.blob,
    required this.heroAsset,
    required this.heroLabel,
    this.chips = false,
  });

  final bool short;
  final bool narrow;
  final Color ink;
  final Color muted;
  final Color blue;
  final Color skip;
  final VoidCallback onSkip;
  final Widget header;
  final List<_TitlePart> title;
  final String body;
  final Color blob;
  final String heroAsset;
  final String heroLabel;
  final bool chips;

  @override
  Widget build(BuildContext context) {
    final hPad = narrow ? 18.0 : 24.0;
    final titleSize = short ? 24.0 : (narrow ? 26.0 : 30.0);
    final bodySize = short ? 13.5 : 15.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, short ? 4 : 8, hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: header),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: skip,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(48, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Skip'),
              ),
            ],
          ),
          SizedBox(height: short ? 12 : 20),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: titleSize,
                height: 1.18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
              children: [
                for (final part in title)
                  TextSpan(
                    text: part.text,
                    style: TextStyle(color: part.accent ? blue : ink),
                  ),
              ],
            ),
            softWrap: true,
          ),
          SizedBox(height: short ? 8 : 10),
          Text(
            body,
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: bodySize,
              height: 1.45,
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: short ? 8 : 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 0,
                      height: box.maxHeight * 0.72,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 1.1,
                            colors: [
                              blob.withValues(alpha: 0.5),
                              blob.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (chips) ...[
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _Chip(
                          icon: Icons.description_rounded,
                          color: const Color(0xFF8B5CF6),
                          label: 'Mock Tests',
                          compact: short || narrow,
                        ),
                      ),
                      Positioned(
                        top: short ? 4 : 8,
                        right: 0,
                        child: _Chip(
                          icon: Icons.smart_toy_outlined,
                          color: blue,
                          label: 'AI Feedback',
                          compact: short || narrow,
                        ),
                      ),
                      Positioned(
                        top: short ? 44 : 54,
                        left: 4,
                        child: _Chip(
                          icon: Icons.article_outlined,
                          color: const Color(0xFFEF4444),
                          label: 'Previous Year Papers',
                          compact: short || narrow,
                        ),
                      ),
                      Positioned(
                        top: short ? 48 : 60,
                        right: 4,
                        child: _Chip(
                          icon: Icons.bar_chart_rounded,
                          color: const Color(0xFF10B981),
                          label: 'Track Progress',
                          compact: short || narrow,
                        ),
                      ),
                    ],
                    Positioned.fill(
                      top: chips ? (short ? 72.0 : 88.0) : 0,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: narrow ? 8 : 16,
                        ),
                        child: Image.asset(
                          heroAsset,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.high,
                          semanticLabel: heroLabel,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom chrome ────────────────────────────────────────────────────────────

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.index,
    required this.pageCount,
    required this.isFirst,
    required this.isLast,
    required this.short,
    required this.muted,
    required this.blue,
    required this.blueDeep,
    required this.dotInactive,
    required this.onBack,
    required this.onNext,
    required this.onGetStarted,
    required this.onSignIn,
    required this.onDotTap,
  });

  final int index;
  final int pageCount;
  final bool isFirst;
  final bool isLast;
  final bool short;
  final Color muted;
  final Color blue;
  final Color blueDeep;
  final Color dotInactive;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CurveTopPainter(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          short ? 18 : 24,
          short ? 28 : 34,
          short ? 18 : 24,
          short ? 12 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (i) {
                final active = i == index;
                return Semantics(
                  button: true,
                  selected: active,
                  label: 'Onboarding page ${i + 1} of $pageCount',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDotTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 8,
                        width: active ? 22 : 8,
                        decoration: BoxDecoration(
                          color: active ? blue : dotInactive,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: short ? 12 : 16),
            if (isLast)
              _GetStartedBlock(
                blue: blue,
                blueDeep: blueDeep,
                muted: muted,
                short: short,
                onGetStarted: onGetStarted,
                onSignIn: onSignIn,
              )
            else
              _StepRow(
                isFirst: isFirst,
                muted: muted,
                blue: blue,
                short: short,
                onBack: onBack,
                onNext: onNext,
              ),
          ],
        ),
      ),
    );
  }
}

class _CurveTopPainter extends CustomPainter {
  const _CurveTopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 28)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, 28)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0D2052).withValues(alpha: 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.isFirst,
    required this.muted,
    required this.blue,
    required this.short,
    required this.onBack,
    required this.onNext,
  });

  final bool isFirst;
  final Color muted;
  final Color blue;
  final bool short;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final circle = short ? 46.0 : 52.0;

    return Row(
      children: [
        if (!isFirst)
          TextButton(
            onPressed: onBack,
            style: TextButton.styleFrom(
              foregroundColor: muted,
              minimumSize: const Size(48, 44),
              textStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: short ? 15 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Back'),
          )
        else
          const SizedBox(width: 56),
        const Spacer(),
        TextButton(
          onPressed: onNext,
          style: TextButton.styleFrom(
            foregroundColor: blue,
            minimumSize: const Size(48, 44),
            textStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: short ? 15 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Next'),
        ),
        const SizedBox(width: 4),
        Material(
          color: blue,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onNext,
            child: SizedBox(
              width: circle,
              height: circle,
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GetStartedBlock extends StatelessWidget {
  const _GetStartedBlock({
    required this.blue,
    required this.blueDeep,
    required this.muted,
    required this.short,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final Color blue;
  final Color blueDeep;
  final Color muted;
  final bool short;
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: short ? 48 : 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(colors: [blue, blueDeep]),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onGetStarted,
                borderRadius: BorderRadius.circular(28),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: short ? 10 : 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
            GestureDetector(
              onTap: onSignIn,
              child: Text(
                'Sign In',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: blue,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PragyuLogo(height: 44),
        SizedBox(height: 6),
        Text(
          'Learn • Practice • Grow',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A93A8),
          ),
        ),
      ],
    );
  }
}

class _AccentIcon extends StatelessWidget {
  const _AccentIcon({
    required this.background,
    required this.iconColor,
    required this.icon,
  });

  final Color background;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.color,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2052).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D2052),
            ),
          ),
        ],
      ),
    );
  }
}
