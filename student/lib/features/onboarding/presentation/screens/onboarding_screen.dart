import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/widgets/primary_button.dart';
import 'package:student_mobile/features/onboarding/data/onboarding_store.dart';
import 'package:student_mobile/features/onboarding/data/prefs_onboarding_store.dart';
import 'package:student_mobile/features/onboarding/presentation/widgets/onboarding_slide_view.dart';

/// S-06 Onboarding tips — optional once; Learn / Tests / Alerts.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.onboardingStore,
    this.forceShow = false,
  });

  final OnboardingStore? onboardingStore;

  /// When true, always show slides (useful in tests).
  final bool forceShow;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingStore _store =
      widget.onboardingStore ?? PrefsOnboardingStore();
  final _controller = PageController();

  bool _ready = false;
  int _index = 0;

  bool get _isLast => _index >= onboardingSlides.length - 1;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!widget.forceShow) {
      final done = await _store.hasCompleted();
      if (!mounted) return;
      if (done) {
        _goHome(replace: true);
        return;
      }
    }
    setState(() => _ready = true);
  }

  Future<void> _finish() async {
    await _store.markCompleted();
    if (!mounted) return;
    _goHome(replace: true);
  }

  void _goHome({required bool replace}) {
    if (replace) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: !_ready
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: onboardingSlides.length,
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        itemBuilder: (context, index) {
                          return OnboardingSlideView(
                            slide: onboardingSlides[index],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(onboardingSlides.length, (
                              i,
                            ) {
                              final active = i == _index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                height: 8,
                                width: active ? 22 : 8,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.brand
                                      : AppColors.brandSoft,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            label: _isLast ? 'Get started' : 'Next',
                            onPressed: _next,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
