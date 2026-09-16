import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/notes_bookmarks/domain/notes_bookmarks_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

abstract class NotesBookmarksGateway {
  Future<NotesBookmarksSnapshot> loadLibrary();

  Future<StudyNote> createNote({
    required String body,
    String? title,
  });

  Future<void> deleteNote(String noteId);

  Future<void> removeBookmark(String bookmarkId);
}

class NotesBookmarksRepository implements NotesBookmarksGateway {
  NotesBookmarksRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<NotesBookmarksSnapshot> loadLibrary() async {
    final session = await _requireSession();
    final notesFuture = _listNotes(session);
    final bookmarksFuture = _listBookmarks(session);
    final feedbackFuture = _listFeedback(session);
    final notes = await notesFuture;
    final bookmarks = await bookmarksFuture;
    final feedback = await feedbackFuture;
    return NotesBookmarksSnapshot(
      notes: notes,
      bookmarks: bookmarks,
      feedback: feedback,
    );
  }

  @override
  Future<StudyNote> createNote({
    required String body,
    String? title,
  }) async {
    final text = body.trim();
    if (text.isEmpty) {
      throw ArgumentError('Note body is required');
    }
    final session = await _requireSession();
    final envelope = await _api.post(
      '/students/me/learning/notes',
      body: {
        'body': text,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return StudyNote.fromJson(_asMap(envelope['data']));
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final id = noteId.trim();
    if (id.isEmpty) return;
    final session = await _requireSession();
    await _api.delete(
      '/students/me/learning/notes/$id',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> removeBookmark(String bookmarkId) async {
    final id = bookmarkId.trim();
    if (id.isEmpty) return;
    final session = await _requireSession();
    await _api.delete(
      '/students/me/learning/bookmarks/$id',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<List<StudyNote>> _listNotes(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me/learning/notes',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseList(envelope['data'], StudyNote.fromJson);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ContentBookmark>> _listBookmarks(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me/learning/bookmarks',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseList(envelope['data'], ContentBookmark.fromJson);
    } catch (_) {
      return const [];
    }
  }

  Future<List<FeedbackReportItem>> _listFeedback(SessionContext session) async {
    try {
      final profileId = await _loadStudentProfileId(session);
      final envelope = await _api.get(
        '/submissions',
        query: {
          'page': '1',
          'per_page': '50',
          if (profileId != null) 'student_profile_id': profileId,
          'sort': '-submitted_at',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];

      final titles = await _assessmentTitles(session);
      final out = <FeedbackReportItem>[];
      for (final row in data) {
        if (row is! Map) continue;
        final map = row.map((k, v) => MapEntry(k.toString(), v));
        final summary = SubmissionSummary.fromJson(map);
        if (summary.id.isEmpty || summary.isDraft) continue;
        if (!SubmissionPipeline.isReady(summary.status)) continue;
        out.add(
          FeedbackReportItem.fromSubmissionJson(map, titles: titles),
        );
      }
      return out;
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
    } catch (_) {
      return null;
    }
  }

  List<T> _parseList<T>(
    Object? data,
    T Function(Map<String, dynamic>) map,
  ) {
    if (data is! List) return const [];
    final out = <T>[];
    for (final row in data) {
      if (row is! Map) continue;
      final item = map(row.map((k, v) => MapEntry(k.toString(), v)));
      out.add(item);
    }
    return out;
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
