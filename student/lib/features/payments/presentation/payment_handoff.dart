import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// Opens a payment URL in an in-app browser when possible, else external.
Future<bool> launchPaymentHandoff(Uri uri) async {
  try {
    final inApp = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (inApp) return true;
  } catch (_) {
    // Fall through to external browser.
  }
  try {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Explains that checkout continues in the browser before leaving the app.
Future<bool> confirmPaymentHandoff(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Continue in browser'),
      content: const Text(
        'You’ll complete payment in a secure browser window. '
        'When you’re done, return here — we’ll check whether payment succeeded.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Sticky panel while waiting for gateway completion.
class PaymentWaitingBanner extends StatelessWidget {
  const PaymentWaitingBanner({
    super.key,
    required this.onConfirm,
    required this.onOpenAgain,
    required this.onDismiss,
    this.confirming = false,
    this.confirmLabel = 'I’ve paid — confirm',
  });

  final VoidCallback onConfirm;
  final VoidCallback onOpenAgain;
  final VoidCallback onDismiss;
  final bool confirming;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Waiting for payment',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Finish checkout in the browser, then confirm here. '
            'We’ll also check automatically when you return to the app.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: confirming ? null : onConfirm,
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            child: Text(confirming ? 'Confirming…' : confirmLabel),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: confirming ? null : onOpenAgain,
            child: const Text('Open payment again'),
          ),
          TextButton(
            onPressed: confirming ? null : onDismiss,
            child: const Text('Cancel waiting'),
          ),
        ],
      ),
    );
  }
}
