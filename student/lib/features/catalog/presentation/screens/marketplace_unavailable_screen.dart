import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/theme/app_theme.dart';

/// Shown when org marketplace access is disabled.
class MarketplaceUnavailableScreen extends StatelessWidget {
  const MarketplaceUnavailableScreen({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final message = (reason != null && reason!.trim().isNotEmpty)
        ? reason!.trim()
        : 'Marketplace is not available for your institute right now.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.storefront_outlined,
                size: 56,
                color: AppColors.muted,
              ),
              const SizedBox(height: 20),
              Text(
                'Marketplace unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
