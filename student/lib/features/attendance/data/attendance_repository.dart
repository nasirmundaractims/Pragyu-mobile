import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/attendance/domain/attendance_models.dart';

class MissingStudentProfileException implements Exception {
  const MissingStudentProfileException([
    this.message = 'Link a student profile to view your attendance.',
  ]);

  final String message;

  @override
  String toString() => message;
}

abstract class AttendanceGateway {
  Future<AttendanceSummary> loadSummary();
}

class AttendanceRepository implements AttendanceGateway {
  AttendanceRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<AttendanceSummary> loadSummary() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw const MissingStudentProfileException();
    }

    try {
      final envelope = await _api.get(
        '/attendance/students/$profileId/summary',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return AttendanceSummary.fromJson(
        _asMap(envelope['data']),
        studentProfileId: profileId,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        message:
            "Couldn't load attendance. Ask your institute if attendance tracking is turned on, then try again.",
        statusCode: 0,
      );
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
