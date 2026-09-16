import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// S-49 hub segments — attempts vs evaluated scores.
enum PastResultsSegment { attempts, scores }

/// Attempt list filters (mirrors student-web submissions tabs).
enum SubmissionHistoryTab { all, processing, feedback, completed }

enum SubmissionHistoryBucket { processing, feedback, completed, other }

const _feedbackWindow = Duration(days: 14);

SubmissionHistoryBucket bucketSubmission(
  SubmissionSummary item, {
  DateTime? now,
}) {
  if (SubmissionPipeline.isPending(item.status)) {
    return SubmissionHistoryBucket.processing;
  }
  if (SubmissionPipeline.isReady(item.status)) {
    final stamp = item.evaluatedAt ?? item.submittedAt;
    if (stamp != null) {
      final age = (now ?? DateTime.now()).difference(stamp);
      if (age < _feedbackWindow) {
        return SubmissionHistoryBucket.feedback;
      }
    }
    return SubmissionHistoryBucket.completed;
  }
  return SubmissionHistoryBucket.other;
}

bool matchesSubmissionTab(
  SubmissionSummary item,
  SubmissionHistoryTab tab, {
  DateTime? now,
}) {
  if (tab == SubmissionHistoryTab.all) return true;
  return bucketSubmission(item, now: now) ==
      switch (tab) {
        SubmissionHistoryTab.processing =>
          SubmissionHistoryBucket.processing,
        SubmissionHistoryTab.feedback => SubmissionHistoryBucket.feedback,
        SubmissionHistoryTab.completed => SubmissionHistoryBucket.completed,
        SubmissionHistoryTab.all => SubmissionHistoryBucket.other,
      };
}

class PastResultsSnapshot {
  const PastResultsSnapshot({
    this.submissions = const [],
    this.assessmentTitles = const {},
  });

  final List<SubmissionSummary> submissions;
  final Map<String, String> assessmentTitles;

  List<SubmissionSummary> get attempts =>
      submissions.where((item) => !item.isDraft).toList(growable: false);

  List<SubmissionSummary> get scores => attempts
      .where((item) => SubmissionPipeline.isReady(item.status))
      .toList(growable: false);

  int get processingCount => attempts
      .where(
        (item) => bucketSubmission(item) == SubmissionHistoryBucket.processing,
      )
      .length;

  int get feedbackReadyCount => attempts
      .where(
        (item) => bucketSubmission(item) == SubmissionHistoryBucket.feedback,
      )
      .length;

  int get completedCount => attempts
      .where(
        (item) => bucketSubmission(item) == SubmissionHistoryBucket.completed,
      )
      .length;

  double? get averagePercentage {
    final values = scores
        .map((item) => item.percentage)
        .whereType<double>()
        .toList(growable: false);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? get bestPercentage {
    final values = scores
        .map((item) => item.percentage)
        .whereType<double>()
        .toList(growable: false);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  String titleFor(String assessmentId) {
    final title = assessmentTitles[assessmentId]?.trim();
    if (title != null && title.isNotEmpty) return title;
    if (assessmentId.length >= 8) {
      return 'Assessment ${assessmentId.substring(0, 8)}…';
    }
    return 'Assessment';
  }

  List<SubmissionSummary> filteredAttempts(
    SubmissionHistoryTab tab, {
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    return attempts.where((item) {
      if (!matchesSubmissionTab(item, tab)) return false;
      if (q.isEmpty) return true;
      final title = titleFor(item.assessmentId).toLowerCase();
      return title.contains(q) ||
          item.status.toLowerCase().contains(q) ||
          item.id.toLowerCase().contains(q);
    }).toList(growable: false);
  }
}

String formatRelativeTime(DateTime? value) {
  if (value == null) return 'Recently';
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) {
    final mins = diff.inMinutes;
    return '$mins minute${mins == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 14) {
    final days = diff.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
  return _formatDate(value);
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String formatPercent(double? value) {
  if (value == null) return '—';
  if (value == value.roundToDouble()) return '${value.round()}%';
  return '${value.toStringAsFixed(1)}%';
}

String deriveAiGrade(double? percentage) {
  if (percentage == null) return '—';
  if (percentage >= 90) return 'A';
  if (percentage >= 80) return 'B';
  if (percentage >= 70) return 'C';
  if (percentage >= 60) return 'D';
  return 'E';
}

bool submissionIncludesMedia(SubmissionSummary item) {
  final media = item.metadata['media_files'];
  if (media is List && media.isNotEmpty) return true;
  final answers = item.metadata['answers'];
  if (answers is Map) {
    for (final value in answers.values) {
      if (value is Map && value['images'] is List) {
        final images = value['images'] as List;
        if (images.isNotEmpty) return true;
      }
    }
  }
  return false;
}
