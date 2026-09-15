import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/widgets/primary_button.dart';
import 'package:student_mobile/app/widgets/secondary_button.dart';
import 'package:student_mobile/core/config/app_config.dart';

/// S-02 Welcome — sign-in / create-account entry only (not S-03 Sign in).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appName = AppConfig.instance.appName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.brandSoft,
                AppColors.background,
                Color(0xFFEEF2F7),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            appName.isNotEmpty ? appName[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        appName,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.6,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your classes, tests, and learning — in one calm place.',
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.45,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(flex: 3),
                      PrimaryButton(
                        label: 'Sign in',
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.signIn);
                        },
                      ),
                      const SizedBox(height: 12),
                      SecondaryButton(
                        label: 'Create account',
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.createAccountStub);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'By continuing you agree to your institute’s terms of use.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.muted.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
