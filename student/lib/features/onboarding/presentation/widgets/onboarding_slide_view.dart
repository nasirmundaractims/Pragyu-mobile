import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}

const onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    title: 'Learn',
    body:
        'Open your courses, join live classes, and find study materials in one place.',
    icon: Icons.menu_book_rounded,
  ),
  OnboardingSlide(
    title: 'Tests',
    body:
        'Take assessments, track what’s due, and review results when they’re ready.',
    icon: Icons.quiz_outlined,
  ),
  OnboardingSlide(
    title: 'Alerts',
    body:
        'Stay on top of announcements, deadlines, and replies — without the noise.',
    icon: Icons.notifications_active_outlined,
  ),
];

class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({super.key, required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.center,
            child: Icon(slide.icon, size: 44, color: AppColors.brand),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
