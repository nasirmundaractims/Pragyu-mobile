import 'package:flutter/material.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/payments/domain/payments_models.dart';

/// Detects credit/quota exhaustion from API errors.
bool isCreditExhaustedError(Object error) {
  if (error is! ApiException) return false;
  final code = (error.code ?? '').toUpperCase();
  if (code.contains('CREDIT_INSUFFICIENT') ||
      code.contains('INSUFFICIENT_CREDIT') ||
      code.contains('CREDITS_EXHAUSTED') ||
      code.contains('QUOTA_EXHAUSTED') ||
      code.contains('CREDIT_WALLET')) {
    return true;
  }
  final message = error.message.toLowerCase();
  return message.contains('insufficient credit') ||
      message.contains('out of credit') ||
      message.contains('credits exhausted') ||
      message.contains('credit balance') ||
      message.contains('not enough credit') ||
      message.contains('quota exhausted') ||
      message.contains('included credits');
}

/// Shows a snackbar with optional navigation to Payments → AI Balance.
void showCreditAwareError(
  BuildContext context,
  Object error, {
  String fallback = 'Something went wrong. Try again.',
}) {
  final message = error is ApiException ? error.message : fallback;
  final exhausted = isCreditExhaustedError(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        exhausted
            ? (message.isNotEmpty
                ? message
                : 'You are out of AI credits. Buy a pack to continue.')
            : message,
      ),
      behavior: SnackBarBehavior.floating,
      action: exhausted
          ? SnackBarAction(
              label: 'Buy credits',
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.payments,
                  arguments: PaymentsViewId.balance,
                );
              },
            )
          : null,
    ),
  );
}
