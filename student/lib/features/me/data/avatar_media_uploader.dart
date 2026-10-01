import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';

const _maxAvatarBytes = 5 * 1024 * 1024;
const _allowedAvatarMime = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
};

/// Slice 5.3 — upload avatar bytes via Media sessions, return media_file_id.
class AvatarMediaUploader {
  AvatarMediaUploader({
    ApiClient? apiClient,
    SessionService? sessionService,
    http.Client? httpClient,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService(),
        _http = httpClient ?? http.Client();

  final ApiClient _api;
  final SessionService _session;
  final http.Client _http;

  Future<String> uploadAvatarBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required String profileId,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Image bytes are required');
    }
    if (bytes.length > _maxAvatarBytes) {
      throw ApiException(
        message: 'Photo must be 5 MB or smaller.',
        statusCode: 0,
      );
    }

    final resolvedMime = _resolveMimeType(fileName, mimeType);
    if (!_allowedAvatarMime.contains(resolvedMime) &&
        !resolvedMime.startsWith('image/')) {
      throw ApiException(
        message: 'Use JPG, PNG, or WebP for your photo.',
        statusCode: 0,
      );
    }

    final session = await _requireSession();
    await _ensureStorageQuota(session, bytes.length);

    final uploadSession = await _api.post(
      '/media/upload-sessions',
      body: {
        'file_name': fileName,
        'mime_type': resolvedMime,
        'file_size_bytes': bytes.length,
        'reference_type': 'user_profile',
        'reference_id': profileId,
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final sessionData = _asMap(uploadSession['data']);
    final sessionId = sessionData['id']?.toString() ?? '';
    final presignedUrl = sessionData['presigned_url']?.toString();
    if (sessionId.isEmpty || presignedUrl == null || presignedUrl.isEmpty) {
      throw ApiException(
        message: 'Upload session did not return a presigned URL.',
        statusCode: 0,
      );
    }

    final put = await _http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': resolvedMime},
      body: bytes,
    );
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw ApiException(
        message: 'Failed to upload photo to storage.',
        statusCode: put.statusCode,
      );
    }

    final checksum = sha256.convert(bytes).toString();
    final confirmed = await _api.post(
      '/media/upload-sessions/$sessionId/confirm',
      body: {'checksum': checksum},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final confirmedData = _asMap(confirmed['data']);
    final mediaFileId = confirmedData['media_file_id']?.toString() ??
        confirmedData['id']?.toString() ??
        '';
    if (mediaFileId.isEmpty) {
      throw ApiException(
        message: 'Upload confirmed but media id was missing.',
        statusCode: 0,
      );
    }
    return mediaFileId;
  }

  Future<void> _ensureStorageQuota(
    SessionContext session,
    int bytes,
  ) async {
    try {
      final envelope = await _api.get(
        '/media/storage-usage',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      final remaining = data['remaining_bytes'];
      if (remaining is num && remaining >= 0 && bytes > remaining) {
        throw ApiException(
          message:
              'Organization storage quota exceeded. Free space or upgrade your plan.',
          statusCode: 0,
        );
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      // Quota endpoint may be unavailable; proceed and let upload fail loudly.
    }
  }

  String _resolveMimeType(String fileName, String mimeType) {
    final trimmed = mimeType.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw ApiException(
        code: 'AUTH_REQUIRED',
        message: 'Please sign in again.',
        statusCode: 401,
      );
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
