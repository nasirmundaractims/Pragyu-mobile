import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/study_planner/domain/study_planner_models.dart';

abstract class StudyPlannerGateway {
  Future<StudyPlannerSnapshot> loadPlanner();

  Future<StudyPlan> generateWeeklyPlan({required String studentProfileId});

  Future<LearningGoal> completeGoal(String goalId);
}

class StudyPlannerRepository implements StudyPlannerGateway {
  StudyPlannerRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<StudyPlannerSnapshot> loadPlanner() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Student profile is required for the study planner.',
        statusCode: 0,
      );
    }

    final plansFuture = _listPlans(session, profileId);
    final goalsFuture = _listGoals(session, profileId);
    final plans = await plansFuture;
    final goals = await goalsFuture;

    // Hydrate first plan items if list payload omitted them.
    final hydrated = <StudyPlan>[];
    for (var i = 0; i < plans.length; i++) {
      final plan = plans[i];
      if (plan.sessions.isNotEmpty || plan.id.isEmpty) {
        hydrated.add(plan);
        continue;
      }
      try {
        hydrated.add(await _getPlan(session, profileId, plan.id));
      } catch (_) {
        hydrated.add(plan);
      }
    }

    return StudyPlannerSnapshot(
      studentProfileId: profileId,
      plans: hydrated,
      goals: goals,
      activePlanId: hydrated.isEmpty ? null : hydrated.first.id,
    );
  }

  @override
  Future<StudyPlan> generateWeeklyPlan({
    required String studentProfileId,
  }) async {
    final id = studentProfileId.trim();
    if (id.isEmpty) {
      throw ArgumentError('studentProfileId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.post(
      '/learning/plans/generate',
      body: {
        'student_profile_id': id,
        'plan_type': 'weekly',
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final plan = StudyPlan.fromJson(_asMap(envelope['data']));
    if (plan.id.isEmpty) {
      throw ApiException(
        message: 'Unable to generate study plan.',
        statusCode: 0,
      );
    }
    if (plan.sessions.isNotEmpty) return plan;
    try {
      return await _getPlan(session, id, plan.id);
    } catch (_) {
      return plan;
    }
  }

  @override
  Future<LearningGoal> completeGoal(String goalId) async {
    final id = goalId.trim();
    if (id.isEmpty) {
      throw ArgumentError('goalId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.post(
      '/learning/goals/$id/complete',
      body: const {},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return LearningGoal.fromJson(_asMap(envelope['data']));
  }

  Future<List<StudyPlan>> _listPlans(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/learning/plans',
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (row) => StudyPlan.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((plan) => plan.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<StudyPlan> _getPlan(
    SessionContext session,
    String studentProfileId,
    String planId,
  ) async {
    final envelope = await _api.get(
      '/learning/plans/$planId',
      query: {'student_profile_id': studentProfileId},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return StudyPlan.fromJson(_asMap(envelope['data']));
  }

  Future<List<LearningGoal>> _listGoals(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/learning/goals',
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (row) => LearningGoal.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((goal) => goal.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
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
}
