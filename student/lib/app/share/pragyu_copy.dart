import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Canonical copy / share feedback for the Student App (Phase 1).
abstract final class PragyuCopyMessages {
  static const linkCopied = 'Link copied';
  static const answerCopied = 'Answer copied';
  static const summaryCopied = 'Summary copied';
  static const messageCopied = 'Message copied';
}

/// Floating snackbar used after every successful copy action.
void showPragyuCopiedSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
    ),
  );
}

/// Copies [text] and shows a consistent Pragyu snackbar.
Future<void> copyPragyuText(
  BuildContext context, {
  required String text,
  String message = PragyuCopyMessages.linkCopied,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showPragyuCopiedSnackBar(context, message);
}

/// Brands pasted/shared body text without changing URLs.
String brandPragyuCopiedBody(String content, {String via = 'Pragyu'}) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return '— via $via';
  if (RegExp(r'via\s+pragyu|pragyu\s+ai', caseSensitive: false).hasMatch(trimmed)) {
    return trimmed;
  }
  return '$trimmed\n\n— via $via';
}

/// Share caption for titles (message body only — never mutates the link).
String brandPragyuShareCaption(String title, {String? detail}) {
  final name = title.trim().isEmpty ? 'this content' : title.trim();
  final buffer = StringBuffer('Learn on Pragyu — $name');
  final extra = detail?.trim();
  if (extra != null && extra.isNotEmpty) {
    buffer
      ..writeln()
      ..write(extra);
  }
  return buffer.toString();
}
