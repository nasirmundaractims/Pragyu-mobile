import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// Holding screen after S-06. S-10 Home is next.
class HomeStubScreen extends StatelessWidget {
  const HomeStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 32),
              Text(
                'Home',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Auth entry is complete through S-06 Onboarding tips.\n\n'
                'Next up: S-10 Home (Today + next actions).',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
