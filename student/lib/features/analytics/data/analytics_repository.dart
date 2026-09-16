import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/analytics/domain/analytics_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

abstract class AnalyticsGateway {
  Future<PerformanceSnapshot> loadPerformance();
}

class AnalyticsRepository implements AnalyticsGateway {
  AnalyticsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<PerformanceSnapshot> loadPerformance() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Student profile is required for analytics.',
        statusCode: 0,
      );
    }

    final analyticsFuture = _getMap(session, '/learning/analytics', profileId);
    final progressFuture = _getMap(session, '/learning/progress', profileId);
    final weakFuture = _listTopics(
      session,
      profileId,
      '/learning/mastery/weak-topics',
    );
    final strongFuture = _listTopics(
      session,
      profileId,
      '/learning/mastery/strong-topics',
    );
    final submissionsFuture = _listSubmissions(session, profileId);
    final titlesFuture = _assessmentTitles(session);

    final analytics = await analyticsFuture;
    final progress = await progressFuture;
    final weak = await weakFuture;
    final strong = await strongFuture;
    final submissions = await submissionsFuture;
    final titles = await titlesFuture;

    final evaluated = submissions
        .where((s) => SubmissionPipeline.isReady(s.status))
        .toList(growable: false);

    final scoreTrend = [...evaluated]
      ..sort((a, b) {
        final aTime = (a.evaluatedAt ?? a.submittedAt)?.millisecondsSinceEpoch ?? 0;
        final bTime = (b.evaluatedAt ?? b.submittedAt)?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
    final trendSlice = scoreTrend.length > 12
        ? scoreTrend.sublist(scoreTrend.length - 12)
        : scoreTrend;

    final percentages = evaluated
        .map((s) => s.percentage)
        .whereType<double>()
        .toList(growable: false);
    final overall = percentages.isEmpty
        ? null
        : percentages.reduce((a, b) => a + b) / percentages.length;

    final improvement = trendSlice.length >= 2
        ? (trendSlice.last.percentage ?? 0) - (trendSlice.first.percentage ?? 0)
        : null;

    final subjects = _subjectCards(evaluated, titles);
    final metrics = _asMap(analytics['metrics_json'] ?? analytics['metrics']);
    final learningProgress = _progressValue(progress);
    final practice = _num(metrics['completed_practice_sessions'])?.round() ?? 0;

    return PerformanceSnapshot(
      studentProfileId: profileId,
      overallAverage: overall,
      learningProgress: learningProgress,
      streak: computeSubmissionStreak(submissions.map((s) => s.submittedAt)),
      completedAssessments: evaluated.length,
      practiceSessions: practice,
      improvement: improvement,
      snapshotDate: analytics['snapshot_date']?.toString(),
      periodType: analytics['period_type']?.toString(),
      weakTopics: weak,
      strongTopics: strong,
      subjects: subjects,
      scoreTrend: [
        for (final item in trendSlice)
          ScoreTrendPoint(
            submissionId: item.id,
            assessmentId: item.assessmentId,
            title: titles[item.assessmentId] ?? 'Assessment',
            percentage: item.percentage,
            at: item.evaluatedAt ?? item.submittedAt,
          ),
      ],
      recentTitles: titles,
    );
  }

  List<SubjectPerformance> _subjectCards(
    List<SubmissionSummary> evaluated,
    Map<String, String> titles,
  ) {
    final bySubject = <String, ({String title, List<double> scores, int count})>{};
    for (final submission in evaluated) {
      final subjectId = submission.assessmentId.isEmpty
          ? 'unknown'
          : submission.assessmentId;
      final title = titles[subjectId] ?? 'Test';
      final existing = bySubject[subjectId];
      final scores = [...(existing?.scores ?? const <double>[])];
      if (submission.percentage != null) {
        scores.add(submission.percentage!);
      }
      bySubject[subjectId] = (
        title: existing?.title ?? title,
        scores: scores,
        count: (existing?.count ?? 0) + 1,
      );
    }
    return bySubject.entries.map((entry) {
      final scores = entry.value.scores;
      final average = scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length;
      final improvement =
          scores.length >= 2 ? scores.last - scores.first : null;
      return SubjectPerformance(
        subjectId: entry.key,
        title: entry.value.title,
        count: entry.value.count,
        average: average,
        improvement: improvement,
      );
    }).toList(growable: false)
      ..sort((a, b) => (a.average ?? 0).compareTo(b.average ?? 0));
  }

  double? _progressValue(Map<String, dynamic> progress) {
    final raw = progress['overall_progress'] ??
        progress['progress_percent'] ??
        progress['completion_rate'];
    final n = _num(raw);
    if (n == null) return null;
    return n <= 1 ? n * 100 : n;
  }

  Future<Map<String, dynamic>> _getMap(
    SessionContext session,
    String path,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        path,
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _asMap(envelope['data']);
    } catch (_) {
      return const {};
    }
  }

  Future<List<PerformanceTopic>> _listTopics(
    SessionContext session,
    String studentProfileId,
    String path,
  ) async {
    try {
      final envelope = await _api.get(
        path,
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      final out = <PerformanceTopic>[];
      for (var i = 0; i < data.length; i++) {
        final row = data[i];
        if (row is! Map) continue;
        out.add(
          PerformanceTopic.fromJson(
            row.map((k, v) => MapEntry(k.toString(), v)),
            index: i,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<SubmissionSummary>> _listSubmissions(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/submissions',
        query: {
          'page': '1',
          'per_page': '50',
          'student_profile_id': studentProfileId,
          'sort': '-submitted_at',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (row) => SubmissionSummary.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty && !item.isDraft)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, String>> _assessmentTitles(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/assessments',
        query: {'page': '1', 'per_page': '50'},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const {};
      final out = <String, String>{};
      for (final row in data) {
        if (row is! Map) continue;
        final map = row.map((k, v) => MapEntry(k.toString(), v));
        final id = map['id']?.toString();
        final title = map['title']?.toString();
        if (id != null && id.isNotEmpty && title != null && title.isNotEmpty) {
          out[id] = title;
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<String?> _loadStudentProfileId(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      final id = data['id']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
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
}
