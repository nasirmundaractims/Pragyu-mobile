import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:student_mobile/app/share/pragyu_copy.dart';
import 'package:student_mobile/core/config/app_config.dart';

/// Injected share target for tests (avoids platform channel).
typedef PragyuShareHandler = Future<void> Function({
  required String text,
  String? subject,
});

/// Builds student-web share URLs and invokes the OS share sheet.
abstract final class PragyuShare {
  static PragyuShareHandler? debugHandler;

  static String webBaseUrl() {
    try {
      final configured = AppConfig.instance.studentWebBaseUrl?.trim();
      if (configured != null && configured.isNotEmpty) {
        return configured.replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {
      // AppConfig may be unset in pure unit tests.
    }
    return 'https://pragyu.com';
  }

  static String courseUrl(String courseId) {
    final id = courseId.trim();
    return '${webBaseUrl()}/my-courses/$id';
  }

  static String assessmentUrl(String assessmentId) {
    final id = assessmentId.trim();
    return '${webBaseUrl()}/assessments/$id';
  }

  /// Opens the native share sheet with Pragyu-branded copy.
  static Future<void> share({
    required String title,
    String? detail,
    String? url,
    String? subject,
  }) async {
    final caption = brandPragyuShareCaption(title, detail: detail);
    final buffer = StringBuffer(caption);
    final link = url?.trim();
    if (link != null && link.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..write(link);
    }
    final text = buffer.toString().trim();
    final shareSubject = subject?.trim().isNotEmpty == true
        ? subject!.trim()
        : 'Pragyu · ${title.trim().isEmpty ? 'Learn' : title.trim()}';

    final handler = debugHandler;
    if (handler != null) {
      await handler(text: text, subject: shareSubject);
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: shareSubject),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('PragyuShare failed: $error');
      }
      rethrow;
    }
  }

  /// Convenience for course detail.
  static Future<void> shareCourse({
    required String courseId,
    required String title,
    String? subtitle,
  }) {
    return share(
      title: title,
      detail: subtitle,
      url: courseUrl(courseId),
      subject: 'Pragyu course · $title',
    );
  }

  /// Convenience for assessment / exam.
  static Future<void> shareAssessment({
    required String assessmentId,
    required String title,
    String? detail,
  }) {
    return share(
      title: title,
      detail: detail,
      url: assessmentUrl(assessmentId),
      subject: 'Pragyu exam · $title',
    );
  }

  /// Convenience for mentor / AI answer text (+ optional link).
  static Future<void> shareMentor({
    required String question,
    String? link,
  }) {
    return share(
      title: question.trim().isEmpty ? 'Pragyu AI answer' : question.trim(),
      detail: 'Shared from Pragyu AI Mentor',
      url: link,
      subject: 'Pragyu AI',
    );
  }
}

/// Optional snackbar after a successful share (best-effort; OS sheet may cancel).
void showPragyuSharedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Ready to share'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
}
