/// S-65 My Performance (analytics) models.
library;

class PerformanceTopic {
  const PerformanceTopic({
    required this.id,
    required this.name,
    this.mastery = 0,
  });

  final String id;
  final String name;
  final int mastery;

  factory PerformanceTopic.fromJson(
    Map<String, dynamic> json, {
    int index = 0,
  }) {
    final name = (json['topic_path'] ??
            json['topic'] ??
            json['name'] ??
            json['title'] ??
            json['subject_id'] ??
            json['id'] ??
            'Topic')
        .toString();
    return PerformanceTopic(
      id: json['id']?.toString() ?? 'topic-$index-$name',
      name: name,
      mastery: _pct(
        json['mastery_score'] ??
            json['mastery'] ??
            json['mastery_percent'] ??
            json['score'],
      ),
    );
  }
}

class SubjectPerformance {
  const SubjectPerformance({
    required this.subjectId,
    required this.title,
    required this.count,
    this.average,
    this.improvement,
  });

  final String subjectId;
  final String title;
  final int count;
  final double? average;
  final double? improvement;

  String get statusLabel {
    final avg = average;
    if (avg == null) return 'Getting started';
    if (avg >= 85) return 'Excellent';
    if (avg >= 70) return 'Good';
    if (avg >= 50) return 'Needs practice';
    return 'Weak';
  }
}

class ScoreTrendPoint {
  const ScoreTrendPoint({
    required this.submissionId,
    required this.assessmentId,
    required this.title,
    this.percentage,
    this.at,
  });

  final String submissionId;
  final String assessmentId;
  final String title;
  final double? percentage;
  final DateTime? at;
}

class PerformanceInsight {
  const PerformanceInsight({
    required this.id,
    required this.title,
    required this.detail,
    this.priority = 'medium',
    this.minutes = 20,
  });

  final String id;
  final String title;
  final String detail;
  final String priority;
  final int minutes;

  bool get isHigh => priority == 'high';
}

class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.studentProfileId,
    this.overallAverage,
    this.learningProgress,
    this.streak,
    this.completedAssessments = 0,
    this.practiceSessions = 0,
    this.improvement,
    this.snapshotDate,
    this.periodType,
    this.weakTopics = const [],
    this.strongTopics = const [],
    this.subjects = const [],
    this.scoreTrend = const [],
    this.recentTitles = const {},
  });

  final String studentProfileId;
  final double? overallAverage;
  final double? learningProgress;
  final int? streak;
  final int completedAssessments;
  final int practiceSessions;
  final double? improvement;
  final String? snapshotDate;
  final String? periodType;
  final List<PerformanceTopic> weakTopics;
  final List<PerformanceTopic> strongTopics;
  final List<SubjectPerformance> subjects;
  final List<ScoreTrendPoint> scoreTrend;
  final Map<String, String> recentTitles;

  String get levelLabel {
    final progress = learningProgress ?? overallAverage ?? 0;
    if (progress >= 85) return 'Advanced Learner';
    if (progress >= 50) return 'Explorer';
    return 'Starter';
  }

  List<PerformanceInsight> get insights {
    final out = <PerformanceInsight>[];
    if (improvement != null && improvement != 0) {
      final delta = (improvement! * 10).round() / 10;
      out.add(
        PerformanceInsight(
          id: 'improvement',
          title: improvement! > 0
              ? 'Your overall score improved by $delta%.'
              : 'Your overall score dipped by ${delta.abs()}%.',
          detail: improvement! > 0
              ? 'Keep the momentum — schedule one more practice session this week.'
              : 'A short revision block can help you recover quickly.',
          priority: improvement! > 0 ? 'medium' : 'high',
          minutes: 25,
        ),
      );
    }
    for (final topic in weakTopics.take(2)) {
      out.add(
        PerformanceInsight(
          id: 'weak-${topic.id}',
          title: '${topic.name} needs more attention.',
          detail:
              'Practice focused questions and ask AI Mentor to explain the concept.',
          priority: 'high',
          minutes: 20,
        ),
      );
    }
    if (strongTopics.isNotEmpty) {
      out.add(
        PerformanceInsight(
          id: 'strong-0',
          title: '${strongTopics.first.name} is becoming a strength.',
          detail:
              'Celebrate the progress — try an advanced mock to stretch further.',
          priority: 'low',
          minutes: 30,
        ),
      );
    }
    SubjectPerformance? improving;
    for (final subject in subjects) {
      if ((subject.improvement ?? 0) > 0) {
        improving = subject;
        break;
      }
    }
    if (improving != null) {
      out.add(
        PerformanceInsight(
          id: 'subject-up',
          title: '${improving.title} is trending upward.',
          detail: 'You are ready for the next mock test in this area.',
          priority: 'medium',
          minutes: 40,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        const PerformanceInsight(
          id: 'start',
          title: 'Complete a few assessments to unlock insights.',
          detail:
              'Scores, weak topics, and streak data appear after your first evaluated attempts.',
          priority: 'medium',
          minutes: 30,
        ),
      );
    }
    return out;
  }
}

int computeSubmissionStreak(Iterable<DateTime?> submittedAts, {DateTime? now}) {
  final days = <String>{};
  for (final value in submittedAts) {
    if (value == null) continue;
    final local = value.toLocal();
    days.add(
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}',
    );
  }
  if (days.isEmpty) return 0;

  final anchor = (now ?? DateTime.now()).toLocal();
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  var cursor = DateTime(anchor.year, anchor.month, anchor.day);
  if (!days.contains(key(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(key(cursor))) return 0;
  }

  var streak = 0;
  while (days.contains(key(cursor))) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

int _pct(Object? value) {
  if (value is num) {
    final n = value.toDouble();
    if (n <= 1) return (n * 100).round().clamp(0, 100);
    return n.round().clamp(0, 100);
  }
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null) return 0;
  if (parsed <= 1) return (parsed * 100).round().clamp(0, 100);
  return parsed.round().clamp(0, 100);
}
