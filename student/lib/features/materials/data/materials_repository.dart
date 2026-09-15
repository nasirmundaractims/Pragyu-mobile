import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';

abstract class MaterialsGateway {
  Future<StudyMaterialsSnapshot> loadMaterials({
    String? courseId,
    String? courseTitle,
  });

  Future<MaterialViewerSnapshot> loadMaterialViewer(MaterialViewerArgs args);
}

class MaterialsRepository implements MaterialsGateway {
  MaterialsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<StudyMaterialsSnapshot> loadMaterials({
    String? courseId,
    String? courseTitle,
  }) async {
    final session = await _requireSession();
    final trimmedCourse = courseId?.trim();

    if (trimmedCourse != null && trimmedCourse.isNotEmpty) {
      final items = await _listForCourse(
        session,
        courseId: trimmedCourse,
        courseTitle: courseTitle,
      );
      return StudyMaterialsSnapshot(items: items);
    }

    // Student list API requires course_id — fan-out enrolled courses.
    final courses = await _loadEnrolledCourses(session);
    if (courses.isEmpty) {
      return const StudyMaterialsSnapshot();
    }

    final byId = <String, StudyMaterial>{};
    for (final course in courses) {
      try {
        final items = await _listForCourse(
          session,
          courseId: course.id,
          courseTitle: course.title,
        );
        for (final item in items) {
          byId.putIfAbsent(item.id, () => item);
        }
      } on ApiException {
        // Skip courses that fail individually.
      } catch (_) {
        // Best-effort fan-out.
      }
    }

    final merged = byId.values.toList(growable: false)
      ..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

    return StudyMaterialsSnapshot(items: merged);
  }

  @override
  Future<MaterialViewerSnapshot> loadMaterialViewer(
    MaterialViewerArgs args,
  ) async {
    if (args.isLibraryMode) {
      return _loadLibraryMaterial(args);
    }
    if (args.isResourceMode) {
      return _loadLessonResource(args);
    }
    throw ArgumentError('materialId or resourceId is required');
  }

  Future<MaterialViewerSnapshot> _loadLibraryMaterial(
    MaterialViewerArgs args,
  ) async {
    final id = args.materialId!.trim();
    final session = await _requireSession();

    try {
      final envelope = await _api.get(
        '/students/me/study-materials/$id',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      final map = data is Map
          ? data.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};

      final material = StudyMaterial.fromJson(map);
      final external = _nonEmpty(material.externalUrl) ??
          _nonEmpty(args.externalUrl) ??
          _nonEmpty(args.seed?.externalUrl);
      final mediaId = _nonEmpty(material.mediaFileId) ??
          _nonEmpty(args.mediaFileId) ??
          _nonEmpty(args.seed?.mediaFileId);

      return MaterialViewerSnapshot(
        id: material.id.isEmpty ? id : material.id,
        title: material.title.isEmpty
            ? (args.title?.trim().isNotEmpty == true
                ? args.title!.trim()
                : 'Study material')
            : material.title,
        source: MaterialViewerSource.library,
        typeLabel: material.typeLabel,
        isFree: material.isFree,
        externalUrl: external,
        mediaFileId: mediaId,
        openUrl: _resolveOpenUrl(externalUrl: external, mediaFileId: mediaId),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        final seed = args.seed;
        return MaterialViewerSnapshot(
          id: id,
          title: args.title?.trim().isNotEmpty == true
              ? args.title!.trim()
              : (seed?.title ?? 'Study material'),
          source: MaterialViewerSource.library,
          typeLabel: seed?.typeLabel ??
              _typeLabelFromRaw(args.resourceType) ??
              'Material',
          isLocked: true,
          isFree: seed?.isFree ?? false,
          errorMessage:
              'Purchase or enrollment is required to open this study material.',
        );
      }
      rethrow;
    }
  }

  Future<MaterialViewerSnapshot> _loadLessonResource(
    MaterialViewerArgs args,
  ) async {
    final id = args.resourceId!.trim();
    final title = args.title?.trim().isNotEmpty == true
        ? args.title!.trim()
        : 'Resource';
    final typeLabel =
        _typeLabelFromRaw(args.resourceType) ?? 'Resource';
    final external = _nonEmpty(args.externalUrl);
    final mediaId = _nonEmpty(args.mediaFileId);

    String? openUrl = _resolveOpenUrl(
      externalUrl: external,
      mediaFileId: mediaId,
    );

    if (args.isDownloadable || openUrl == null) {
      try {
        final download = await _downloadResource(id);
        final downloadUrl = _nonEmpty(download.downloadUrl);
        if (downloadUrl != null) {
          openUrl = _absolutizeMaybe(downloadUrl);
        }
        return MaterialViewerSnapshot(
          id: id,
          title: title,
          source: MaterialViewerSource.resource,
          typeLabel: typeLabel,
          externalUrl: external ?? downloadUrl,
          mediaFileId: mediaId ?? download.mediaFileId,
          openUrl: openUrl,
        );
      } on ApiException catch (e) {
        if (openUrl != null) {
          return MaterialViewerSnapshot(
            id: id,
            title: title,
            source: MaterialViewerSource.resource,
            typeLabel: typeLabel,
            externalUrl: external,
            mediaFileId: mediaId,
            openUrl: openUrl,
          );
        }
        if (e.statusCode == 403) {
          return MaterialViewerSnapshot(
            id: id,
            title: title,
            source: MaterialViewerSource.resource,
            typeLabel: typeLabel,
            isLocked: true,
            errorMessage: e.message,
          );
        }
        rethrow;
      }
    }

    return MaterialViewerSnapshot(
      id: id,
      title: title,
      source: MaterialViewerSource.resource,
      typeLabel: typeLabel,
      externalUrl: external,
      mediaFileId: mediaId,
      openUrl: openUrl,
    );
  }

  Future<ResourceDownloadInfo> _downloadResource(String resourceId) async {
    final session = await _requireSession();
    final envelope = await _api.post(
      '/students/me/learning/resources/$resourceId/download',
      body: const {},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final data = envelope['data'];
    final map = data is Map
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    return ResourceDownloadInfo(
      resourceId: map['resource_id']?.toString() ?? resourceId,
      downloadUrl: map['download_url']?.toString(),
      mediaFileId: map['media_file_id']?.toString(),
      downloadId: map['download_id']?.toString(),
      expiresAt: map['expires_at']?.toString(),
    );
  }

  Future<List<StudyMaterial>> _listForCourse(
    SessionContext session, {
    required String courseId,
    String? courseTitle,
  }) async {
    final envelope = await _api.get(
      '/students/me/study-materials',
      query: {'course_id': courseId},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is! List) {
      return const [];
    }

    final title = courseTitle?.trim();
    return data
        .whereType<Map>()
        .map(
          (item) => StudyMaterial.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
            courseId: courseId,
            courseTitle: (title != null && title.isNotEmpty) ? title : null,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<({String id, String title})>> _loadEnrolledCourses(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/students/me/account/courses',
        query: const {'status': 'all'},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) {
        return const [];
      }

      final courses = <({String id, String title})>[];
      for (final raw in data) {
        if (raw is! Map) continue;
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        final id = map['course_id']?.toString() ??
            map['id']?.toString() ??
            '';
        if (id.isEmpty) continue;
        final title = (map['title'] ??
                map['course_name'] ??
                map['name'] ??
                'Course')
            .toString()
            .trim();
        courses.add((id: id, title: title.isEmpty ? 'Course' : title));
      }
      return courses;
    } on ApiException {
      return const [];
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

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String? _typeLabelFromRaw(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    switch (value.toLowerCase()) {
      case 'pdf':
        return 'PDF';
      case 'notes':
        return 'Notes';
      case 'presentation':
        return 'Presentation';
      case 'video':
        return 'Video';
      case 'external_link':
        return 'Link';
      case 'downloadable':
        return 'Download';
      default:
        return value[0].toUpperCase() + value.substring(1);
    }
  }

  static String? _resolveOpenUrl({
    String? externalUrl,
    String? mediaFileId,
  }) {
    final external = _nonEmpty(externalUrl);
    if (external != null) {
      return _absolutizeMaybe(external);
    }
    final mediaId = _nonEmpty(mediaFileId);
    if (mediaId == null) return null;
    return mediaFileDownloadUrl(mediaId);
  }

  static String _absolutizeMaybe(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${_apiOrigin()}$url';
    }
    return url;
  }

  static String mediaFileDownloadUrl(String mediaFileId) {
    return '${_apiOrigin()}/media/files/$mediaFileId/download';
  }

  static String _apiOrigin() {
    final uri = Uri.parse(AppConfig.instance.apiBaseUrl);
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }
}
