import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/exam_workspace/domain/exam_workspace_models.dart';
import 'package:student_mobile/core/storage/platform_stores.dart';
import 'package:student_mobile/features/organization/data/tenant_store.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

abstract class ExamWorkspaceGateway {
  Future<ExamWorkspaceSnapshot> loadWorkspace();
}

class ExamWorkspaceRepository implements ExamWorkspaceGateway {
  ExamWorkspaceRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
    TenantStore? tenantStore,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService(),
        _tenant = tenantStore ?? createTenantStore();

  final ApiClient _api;
  final SessionService _session;
  final TenantStore _tenant;

  @override
  Future<ExamWorkspaceSnapshot> loadWorkspace() async {
    final session = await _requireSession();
    final profile = await _loadStudentProfile(session);
    final profileId = profile['id']?.toString();
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Student profile is required for Exam Workspace.',
        statusCode: 0,
      );
    }

    final orgContextFuture = _getMap(
      session,
      '/students/$profileId/organization-context',
    );
    final academicFuture = _getMap(
      session,
      '/students/$profileId/academic-profile',
    );
    final assessmentsFuture = _listMaps(
      session,
      '/assessments',
      query: {
        'page': '1',
        'per_page': '50',
        'status': 'published',
        'sort': '-scheduled_at',
      },
    );
    final weakFuture = _listMaps(
      session,
      '/learning/mastery/weak-topics',
      query: {'student_profile_id': profileId},
    );
    final strongFuture = _listMaps(
      session,
      '/learning/mastery/strong-topics',
      query: {'student_profile_id': profileId},
    );
    final recsFuture = _listMaps(
      session,
      '/learning/recommendations',
      query: {'student_profile_id': profileId},
    );
    final revisionFuture = _listMaps(
      session,
      '/learning/revision-schedule',
      query: {'student_profile_id': profileId},
    );
    final submissionsFuture = _listSubmissions(session, profileId);
    final orgNameFuture = _tenant.readActiveOrganizationName();

    final orgContext = await orgContextFuture;
    final academic = await academicFuture;
    final assessments = await assessmentsFuture;
    final weakRows = await weakFuture;
    final strongRows = await strongFuture;
    final recRows = await recsFuture;
    final revisionRows = await revisionFuture;
    final submissions = await submissionsFuture;
    final orgName = await orgNameFuture;

    final programId = (academic['program_id'] ??
            _asMap(orgContext['academic_profile'])['program_id'])
        ?.toString();
    Map<String, dynamic> program = const {};
    if (programId != null && programId.isNotEmpty) {
      program = await _getMap(session, '/programs/$programId');
    }

    final profileMeta = {
      ..._asMap(profile['metadata']),
      ..._asMap(_asMap(orgContext['profile'])['metadata']),
    };

    final orgMappings = _listOfMaps(orgContext['organization_mappings']);
    Map<String, dynamic>? orgSettings;
    if (orgMappings.isNotEmpty &&
        patternFromRecord(orgMappings.first) != null) {
      orgSettings = orgMappings.first;
    } else {
      orgSettings = _asMap(_asMap(orgContext['organization'])['settings']);
    }

    final programAssignments = _listOfMaps(orgContext['program_assignments']);
    final programFromAssignment = (programAssignments.isNotEmpty
            ? (programAssignments.first['exam_pattern'] ??
                _asMap(programAssignments.first['program'])['exam_pattern'])
            : null)
        ?.toString();

    final enrollments = _listOfMaps(
      orgContext['enrollments'] ?? orgContext['batch_enrollments'],
    );
    Map<String, dynamic>? batchMeta;
    if (enrollments.isNotEmpty) {
      final first = enrollments.first;
      batchMeta = _asMap(first['metadata']).isNotEmpty
          ? _asMap(first['metadata'])
          : _asMap(first['batch']);
    }

    final assessmentPatterns = assessments
        .map(extractAssessmentExamPattern)
        .whereType<String>()
        .toList(growable: false);

    final exam = resolveExam(
      studentMetadata: profileMeta,
      organizationSettings: orgSettings,
      organizationSlug: orgName,
      programExamPattern:
          program['exam_pattern']?.toString() ?? programFromAssignment,
      batchMetadata: batchMeta,
      assessmentPatterns: assessmentPatterns,
    );
    final display = buildExamDisplay(exam);

    final readinessResult = await _loadReadiness(session, profileId, exam);
    final readiness = readinessResult.data;
    final readinessUnavailable = readinessResult.unavailable;

    final practiceSets = <ExamPracticeSet>[];
    for (final row in assessments) {
      if (!matchesExamPattern(row, exam.pattern)) continue;
      final id = row['id']?.toString() ?? '';
      final title = row['title']?.toString() ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      final type = (row['type'] ?? 'exam').toString();
      final questions = row['questions'];
      final questionCount = _int(row['questions_count']) ??
          (questions is List ? questions.length : 0);
      practiceSets.add(
        ExamPracticeSet(
          id: id,
          title: title,
          type: type,
          description: row['description']?.toString(),
          questionCount: questionCount,
          totalMarks: _int(row['total_marks']),
          deadlineAt: _parseDate(
            row['deadline_at']?.toString() ?? row['scheduled_at']?.toString(),
          ),
          practiceKind: classifyPractice(row, type),
        ),
      );
    }

    final practiceIds = practiceSets.map((e) => e.id).toSet();
    final examSubmissions = exam.pattern == 'general'
        ? submissions
        : submissions
            .where((s) => practiceIds.contains(s.assessmentId))
            .toList(growable: false);

    final evaluated = examSubmissions
        .where((s) => SubmissionPipeline.isReady(s.status))
        .toList(growable: false);
    final pending = examSubmissions
        .where((s) => SubmissionPipeline.isPending(s.status))
        .toList(growable: false);

    final percentages = evaluated
        .map((s) => s.percentage)
        .whereType<double>()
        .toList(growable: false);
    final average = percentages.isEmpty
        ? null
        : percentages.reduce((a, b) => a + b) / percentages.length;

    final upcoming = [...practiceSets]
      ..retainWhere((item) => item.deadlineAt != null)
      ..sort(
        (a, b) => a.deadlineAt!.compareTo(b.deadlineAt!),
      );

    final titles = {
      for (final item in practiceSets) item.id: item.title,
      for (final row in assessments)
        if ((row['id']?.toString() ?? '').isNotEmpty)
          row['id']!.toString(): (row['title']?.toString() ?? 'Assessment'),
    };

    final revisionDue = revisionRows.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      return status != 'completed';
    }).length;

    return ExamWorkspaceSnapshot(
      studentProfileId: profileId,
      exam: exam,
      display: display,
      readinessPct: readinessScore(readiness),
      readinessFactors: _asMap(
        readiness['factors_json'] ?? readiness['factors'],
      ),
      readinessUnavailable: readinessUnavailable,
      weakTopics: weakRows.map(_topicLabel).toList(growable: false),
      strongTopics: strongRows.map(_topicLabel).toList(growable: false),
      practiceSets: practiceSets,
      upcoming: upcoming.take(5).toList(growable: false),
      recommendations: [
        for (var i = 0; i < recRows.length && i < 5; i++)
          ExamRecommendationPreview(
            id: recRows[i]['id']?.toString() ?? 'rec-$i',
            title: (recRows[i]['title'] ??
                    recRows[i]['reason'] ??
                    recRows[i]['topic_path'] ??
                    'Recommendation')
                .toString(),
            reason: (recRows[i]['reason'] ??
                    recRows[i]['content'] ??
                    'Personalized next step')
                .toString(),
          ),
      ],
      recentAttempts: [
        for (final item in examSubmissions.take(6))
          ExamRecentAttempt(
            submission: item,
            title: titles[item.assessmentId] ?? 'Assessment',
          ),
      ],
      pendingCount: pending.length,
      evaluatedCount: evaluated.length,
      averageScore: average,
      streak: workspaceStreak(examSubmissions.map((s) => s.submittedAt)),
      revisionDue: revisionDue,
    );
  }

  Future<({Map<String, dynamic> data, bool unavailable})> _loadReadiness(
    SessionContext session,
    String profileId,
    ResolvedExam exam,
  ) async {
    try {
      final query = <String, String>{
        'student_profile_id': profileId,
      };
      if (exam.pattern != 'general') {
        query['exam_pattern'] = exam.pattern;
      }
      final envelope = await _api.get(
        '/coach/readiness',
        query: query,
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return (data: _asMap(envelope['data']), unavailable: false);
    } catch (_) {
      return (data: const <String, dynamic>{}, unavailable: true);
    }
  }

  Future<Map<String, dynamic>> _loadStudentProfile(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/students/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _asMap(envelope['data']);
    } on ApiException {
      rethrow;
    } catch (_) {
      return const {};
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

  Future<Map<String, dynamic>> _getMap(
    SessionContext session,
    String path,
  ) async {
    try {
      final envelope = await _api.get(
        path,
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _asMap(envelope['data']);
    } catch (_) {
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> _listMaps(
    SessionContext session,
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final envelope = await _api.get(
        path,
        query: query,
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _listOfMaps(envelope['data']);
    } catch (_) {
      return const [];
    }
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  List<Map<String, dynamic>> _listOfMaps(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  String _topicLabel(Map<String, dynamic> row) {
    final value = row['topic_path'] ??
        row['topic'] ??
        row['name'] ??
        row['id'] ??
        'Topic';
    return value.toString();
  }

  int? _int(Object? raw) {
    if (raw is num) return raw.round();
    return int.tryParse(raw?.toString() ?? '');
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
