/// S-66 Exam Workspace (practice hub) models.

import 'package:student_mobile/features/analytics/domain/analytics_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

enum ExamSource {
  studentProfile,
  organization,
  program,
  batch,
  assessment,
  fallback,
}

extension ExamSourceX on ExamSource {
  String get label {
    switch (this) {
      case ExamSource.studentProfile:
        return 'student profile';
      case ExamSource.organization:
        return 'organization';
      case ExamSource.program:
        return 'program';
      case ExamSource.batch:
        return 'batch';
      case ExamSource.assessment:
        return 'assessment';
      case ExamSource.fallback:
        return 'fallback';
    }
  }
}

enum PracticeKind { mock, section, topic, previous, general }

class ResolvedExam {
  const ResolvedExam({
    required this.pattern,
    required this.label,
    required this.hubTitle,
    required this.source,
  });

  final String pattern;
  final String label;
  final String hubTitle;
  final ExamSource source;
}

class ExamAccent {
  const ExamAccent({
    required this.from,
    required this.to,
  });

  final ColorValue from;
  final ColorValue to;
}

/// Lightweight ARGB holder so domain stays Flutter-free.
class ColorValue {
  const ColorValue(this.argb);
  final int argb;
}

class PracticeTypeCard {
  const PracticeTypeCard({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class RoadmapStep {
  const RoadmapStep({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class CoachAction {
  const CoachAction({
    required this.id,
    required this.label,
    required this.prompt,
  });

  final String id;
  final String label;
  final String prompt;
}

class ExamDisplayConfig {
  const ExamDisplayConfig({
    required this.exam,
    required this.accent,
    required this.subtitle,
    required this.practiceTypes,
    required this.roadmap,
    required this.coachActions,
  });

  final ResolvedExam exam;
  final ExamAccent accent;
  final String subtitle;
  final List<PracticeTypeCard> practiceTypes;
  final List<RoadmapStep> roadmap;
  final List<CoachAction> coachActions;
}

class ExamPracticeSet {
  const ExamPracticeSet({
    required this.id,
    required this.title,
    required this.type,
    this.description,
    this.questionCount = 0,
    this.totalMarks,
    this.deadlineAt,
    this.practiceKind = PracticeKind.general,
  });

  final String id;
  final String title;
  final String type;
  final String? description;
  final int questionCount;
  final int? totalMarks;
  final DateTime? deadlineAt;
  final PracticeKind practiceKind;

  String get metaLine {
    final parts = <String>[
      type,
      if (questionCount > 0) '$questionCount questions',
      if (totalMarks != null) '$totalMarks marks',
    ];
    return parts.join(' · ');
  }
}

class ExamRecommendationPreview {
  const ExamRecommendationPreview({
    required this.id,
    required this.title,
    required this.reason,
  });

  final String id;
  final String title;
  final String reason;
}

class ExamTimelineEvent {
  const ExamTimelineEvent({
    required this.id,
    required this.title,
    required this.detail,
    required this.meta,
  });

  final String id;
  final String title;
  final String detail;
  final String meta;
}

class ExamRecentAttempt {
  const ExamRecentAttempt({
    required this.submission,
    required this.title,
  });

  final SubmissionSummary submission;
  final String title;

  bool get isEvaluated => SubmissionPipeline.isReady(submission.status);
}

class ExamWorkspaceSnapshot {
  const ExamWorkspaceSnapshot({
    required this.studentProfileId,
    required this.exam,
    required this.display,
    this.readinessPct,
    this.readinessFactors = const {},
    this.readinessUnavailable = false,
    this.weakTopics = const [],
    this.strongTopics = const [],
    this.practiceSets = const [],
    this.upcoming = const [],
    this.recommendations = const [],
    this.recentAttempts = const [],
    this.pendingCount = 0,
    this.evaluatedCount = 0,
    this.averageScore,
    this.streak = 0,
    this.revisionDue = 0,
  });

  final String studentProfileId;
  final ResolvedExam exam;
  final ExamDisplayConfig display;
  final int? readinessPct;
  final Map<String, dynamic> readinessFactors;
  final bool readinessUnavailable;
  final List<String> weakTopics;
  final List<String> strongTopics;
  final List<ExamPracticeSet> practiceSets;
  final List<ExamPracticeSet> upcoming;
  final List<ExamRecommendationPreview> recommendations;
  final List<ExamRecentAttempt> recentAttempts;
  final int pendingCount;
  final int evaluatedCount;
  final double? averageScore;
  final int streak;
  final int revisionDue;

  int practiceTypeCount(String typeId) {
    return practiceSets.where((item) {
      if (item.practiceKind.name == typeId) return true;
      if (typeId == 'mock' &&
          item.practiceKind == PracticeKind.general &&
          item.type.toLowerCase() == 'exam') {
        return true;
      }
      return false;
    }).length;
  }

  List<ExamTimelineEvent> get timeline {
    final events = <ExamTimelineEvent>[
      for (final item in upcoming.take(3))
        ExamTimelineEvent(
          id: 'up-${item.id}',
          title: 'Upcoming exam',
          detail: item.title,
          meta: item.deadlineAt != null
              ? _formatShortDate(item.deadlineAt!)
              : 'Scheduled',
        ),
      if (revisionDue > 0)
        ExamTimelineEvent(
          id: 'rev',
          title: 'Pending revision',
          detail: '$revisionDue items due',
          meta: 'Revision center',
        ),
      ExamTimelineEvent(
        id: 'today',
        title: "Today's practice",
        detail: weakTopics.isNotEmpty
            ? 'Focus on ${weakTopics.first}'
            : 'Build a ${exam.label} practice block',
        meta: 'Practice hub',
      ),
      ExamTimelineEvent(
        id: 'ai',
        title: 'AI suggestions',
        detail: display.coachActions.isNotEmpty
            ? display.coachActions.first.label
            : 'Ask AI Coach',
        meta: 'AI Coach',
      ),
    ];
    return events;
  }
}

const _knownLabels = <String, String>{
  'gpsc': 'GPSC',
  'upsc': 'UPSC',
  'gsssb': 'GSSSB',
  'bpsc': 'BPSC',
  'rpsc': 'RPSC',
  'mpsc': 'MPSC',
  'ssc': 'SSC',
  'banking': 'Banking',
  'railway': 'Railway',
  'police': 'Police',
  'neet': 'NEET',
  'jee': 'JEE',
  'school': 'School',
  'college': 'College',
  'university': 'University',
  'coaching': 'Coaching',
  'custom': 'Custom',
  'general': 'General',
};

String examLabelFromPattern(String pattern) {
  final key = pattern.trim().toLowerCase();
  if (key.isEmpty) return 'General';
  final known = _knownLabels[key];
  if (known != null) return known;
  return key
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (RegExp(r'^\d+$').hasMatch(part)) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String examHubTitle(String pattern) =>
    '${examLabelFromPattern(pattern)} Practice Hub';

String? patternFromRecord(Map<String, dynamic>? row) {
  if (row == null || row.isEmpty) return null;
  final settings = _asMap(row['settings']);
  final metadata = _asMap(row['metadata']);
  final candidates = [
    row['exam_pattern'],
    row['examPattern'],
    row['exam_slug'],
    row['examSlug'],
    row['target_exam'],
    row['targetExam'],
    row['exam_type'],
    row['examType'],
    settings['exam_pattern'],
    settings['examPattern'],
    settings['exam_slug'],
    settings['default_exam_pattern'],
    settings['defaultExamPattern'],
    metadata['exam_pattern'],
    metadata['examPattern'],
    metadata['exam_slug'],
    metadata['target_exam'],
    metadata['exam'],
  ];
  for (final value in candidates) {
    final text = (value?.toString() ?? '').trim().toLowerCase();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String? extractAssessmentExamPattern(Map<String, dynamic> row) {
  final direct = patternFromRecord(row);
  if (direct != null) return direct;
  final haystack =
      '${row['title'] ?? ''} ${row['description'] ?? ''} ${row['instructions'] ?? ''}'
          .toLowerCase();
  for (final key in _knownLabels.keys) {
    if (key == 'general' || key == 'custom') continue;
    if (haystack.contains(key)) return key;
  }
  return null;
}

bool matchesExamPattern(Map<String, dynamic> row, String pattern) {
  final target = pattern.trim().toLowerCase();
  if (target.isEmpty || target == 'general') return true;
  final found = extractAssessmentExamPattern(row);
  if (found == target) return true;
  final haystack =
      '${row['title'] ?? ''} ${row['description'] ?? ''} ${row['instructions'] ?? ''}'
          .toLowerCase();
  return haystack.contains(target);
}

ResolvedExam resolveExam({
  Map<String, dynamic>? studentMetadata,
  Map<String, dynamic>? organizationSettings,
  String? organizationSlug,
  String? programExamPattern,
  Map<String, dynamic>? batchMetadata,
  List<String> assessmentPatterns = const [],
}) {
  final fromProfile = patternFromRecord(studentMetadata);
  if (fromProfile != null) {
    return _finish(fromProfile, ExamSource.studentProfile);
  }

  final fromOrg = patternFromRecord(organizationSettings);
  if (fromOrg != null) {
    return _finish(fromOrg, ExamSource.organization);
  }

  final slug = (organizationSlug ?? '').toLowerCase();
  if (slug.isNotEmpty) {
    for (final key in _knownLabels.keys) {
      if (key != 'general' && key != 'custom' && slug.contains(key)) {
        return _finish(key, ExamSource.organization);
      }
    }
  }

  final fromProgram = (programExamPattern ?? '').trim().toLowerCase();
  if (fromProgram.isNotEmpty) {
    return _finish(fromProgram, ExamSource.program);
  }

  final fromBatch = patternFromRecord(batchMetadata);
  if (fromBatch != null) {
    return _finish(fromBatch, ExamSource.batch);
  }

  final majority = _majorityPattern(assessmentPatterns);
  if (majority != null) {
    return _finish(majority, ExamSource.assessment);
  }

  return _finish('general', ExamSource.fallback);
}

ExamDisplayConfig buildExamDisplay(ResolvedExam exam) {
  return ExamDisplayConfig(
    exam: exam,
    accent: _accentFor(exam.pattern),
    subtitle: 'Personalized AI preparation workspace for ${exam.label}.',
    practiceTypes: [
      PracticeTypeCard(
        id: 'mock',
        title: 'Mock tests',
        description: 'Full-length ${exam.label} simulations',
      ),
      const PracticeTypeCard(
        id: 'section',
        title: 'Section tests',
        description: 'Focused sectional practice',
      ),
      const PracticeTypeCard(
        id: 'topic',
        title: 'Topic tests',
        description: 'Drill weak areas by topic',
      ),
      const PracticeTypeCard(
        id: 'previous',
        title: 'Previous papers',
        description: 'Past-paper style sets',
      ),
      const PracticeTypeCard(
        id: 'bookmarks',
        title: 'Bookmarks',
        description: 'Saved questions and notes',
      ),
      const PracticeTypeCard(
        id: 'saved',
        title: 'Saved questions',
        description: 'Questions marked for revisit',
      ),
    ],
    roadmap: const [
      RoadmapStep(
        id: 'foundation',
        title: 'Foundation',
        description: 'Build core concepts',
      ),
      RoadmapStep(
        id: 'practice',
        title: 'Practice',
        description: 'Apply through tests',
      ),
      RoadmapStep(
        id: 'revision',
        title: 'Revision',
        description: 'Spaced review cycle',
      ),
      RoadmapStep(
        id: 'mock',
        title: 'Mock test',
        description: 'Exam-day simulation',
      ),
      RoadmapStep(
        id: 'final',
        title: 'Final revision',
        description: 'Polish weak spots',
      ),
    ],
    coachActions: [
      CoachAction(
        id: 'ask',
        label: 'Ask AI',
        prompt:
            'Help me prepare for ${exam.label}. What should I focus on today?',
      ),
      CoachAction(
        id: 'plan',
        label: 'Generate study plan',
        prompt:
            'Create a weekly ${exam.label} study plan using my weak topics and upcoming assessments.',
      ),
      CoachAction(
        id: 'revision',
        label: 'Generate revision plan',
        prompt:
            'Create a ${exam.label} revision plan for my pending weak topics.',
      ),
      CoachAction(
        id: 'analyze',
        label: 'Analyze weak areas',
        prompt:
            'Analyze my weak areas for ${exam.label} and recommend the highest-impact fixes.',
      ),
    ],
  );
}

PracticeKind classifyPractice(Map<String, dynamic> row, String type) {
  final haystack =
      '${row['title'] ?? ''} ${row['description'] ?? ''} $type'.toLowerCase();
  if (haystack.contains('mock')) return PracticeKind.mock;
  if (haystack.contains('section')) return PracticeKind.section;
  if (haystack.contains('previous') || haystack.contains('pyq')) {
    return PracticeKind.previous;
  }
  if (haystack.contains('topic') ||
      type == 'practice' ||
      type == 'quiz') {
    return PracticeKind.topic;
  }
  return PracticeKind.general;
}

int? readinessScore(Map<String, dynamic>? readiness) {
  if (readiness == null || readiness.isEmpty) return null;
  final nested = _asMap(readiness['scores'] ??
      readiness['metrics'] ??
      readiness['summary']);
  final candidates = [
    readiness['overall_score'],
    readiness['readiness_score'],
    readiness['score'],
    readiness['percentage'],
    nested['overall'],
    nested['readiness'],
    nested['score'],
  ];
  for (final value in candidates) {
    final n = _num(value);
    if (n == null) continue;
    return (n <= 1 ? n * 100 : n).round();
  }
  return null;
}

int workspaceStreak(Iterable<DateTime?> submittedAts, {DateTime? now}) =>
    computeSubmissionStreak(submittedAts, now: now);

ResolvedExam _finish(String pattern, ExamSource source) {
  final normalized = pattern.trim().toLowerCase();
  final key = normalized.isEmpty ? 'general' : normalized;
  return ResolvedExam(
    pattern: key,
    label: examLabelFromPattern(key),
    hubTitle: examHubTitle(key),
    source: source,
  );
}

String? _majorityPattern(List<String> patterns) {
  final counts = <String, int>{};
  for (final raw in patterns) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty || key == 'general') continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  String? best;
  var bestCount = 0;
  counts.forEach((key, count) {
    if (count > bestCount) {
      best = key;
      bestCount = count;
    }
  });
  return best;
}

ExamAccent _accentFor(String pattern) {
  switch (pattern) {
    case 'gpsc':
      return const ExamAccent(
        from: ColorValue(0xFFDFF7F1),
        to: ColorValue(0xFFE8F0FF),
      );
    case 'upsc':
      return const ExamAccent(
        from: ColorValue(0xFFE8F0FF),
        to: ColorValue(0xFFF3E8FF),
      );
    case 'ssc':
      return const ExamAccent(
        from: ColorValue(0xFFFFF3E4),
        to: ColorValue(0xFFE8FAF5),
      );
    case 'banking':
      return const ExamAccent(
        from: ColorValue(0xFFE8FAF5),
        to: ColorValue(0xFFECFEFF),
      );
    case 'railway':
      return const ExamAccent(
        from: ColorValue(0xFFFEF3C7),
        to: ColorValue(0xFFE0E7FF),
      );
    case 'school':
      return const ExamAccent(
        from: ColorValue(0xFFFCE7F3),
        to: ColorValue(0xFFE0F2FE),
      );
    case 'university':
      return const ExamAccent(
        from: ColorValue(0xFFEEF2FF),
        to: ColorValue(0xFFECFDF5),
      );
    default:
      return const ExamAccent(
        from: ColorValue(0xFFF1F5F9),
        to: ColorValue(0xFFECFEFF),
      );
  }
}

String _formatShortDate(DateTime value) {
  const months = [
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
  final local = value.toLocal();
  return '${months[local.month - 1]} ${local.day}';
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

double? _num(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}
