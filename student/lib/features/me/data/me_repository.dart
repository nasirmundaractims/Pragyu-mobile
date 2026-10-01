import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/auth_session_events.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/core/storage/platform_stores.dart';
import 'package:student_mobile/features/auth/data/token_store.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
import 'package:student_mobile/features/me/data/avatar_media_uploader.dart';
import 'package:student_mobile/features/me/domain/me_models.dart';
import 'package:student_mobile/features/organization/data/tenant_store.dart';

abstract class MeGateway {
  Future<MeSnapshot> loadMe();

  Future<UserProfileSummary> updateProfile({
    required String displayName,
    String? phone,
  });

  /// Slice 5.3 — Media upload + PATCH avatar_media_id, then resolve display URL.
  Future<UserProfileSummary> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  });

  Future<UserProfileSummary> clearAvatar();

  Future<void> setEmailNotifications({
    required String studentProfileId,
    required bool enabled,
  });

  Future<void> setDailyStudyHours({
    required String studentProfileId,
    required double hours,
  });

  Future<void> signOut();
}

class MeRepository implements MeGateway {
  MeRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
    TokenStore? tokenStore,
    TenantStore? tenantStore,
    AvatarMediaUploader? avatarUploader,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService(),
        _tokens = tokenStore ?? createTokenStore(),
        _tenant = tenantStore ?? createTenantStore(),
        _avatarUploader = avatarUploader ?? AvatarMediaUploader();

  final ApiClient _api;
  final SessionService _session;
  final TokenStore _tokens;
  final TenantStore _tenant;
  final AvatarMediaUploader _avatarUploader;

  @override
  Future<MeSnapshot> loadMe() async {
    final session = await _requireSession();
    final user = session.cachedUser ??
        AuthUser(id: '', email: 'Signed in');

    final orgName = await _tenant.readActiveOrganizationName();
    final orgType = await _tenant.readActiveOrganizationType();
    final profileFuture = _loadStudentProfile(session);
    final userProfileFuture = _loadUserProfile(session);

    final student = await profileFuture;
    final userProfile = await userProfileFuture;

    var emailNotifications = true;
    var studyHours = 2.0;
    if (student != null && student.id.isNotEmpty) {
      final settings = await _loadSettings(session, student.id);
      final preferences = await _loadPreferences(session, student.id);
      emailNotifications = _emailEnabledFromSettings(settings);
      studyHours = _hoursFromPreferences(preferences) ?? studyHours;
    }

    return MeSnapshot(
      user: user.email.isEmpty && userProfile?.displayName != null
          ? AuthUser(
              id: user.id,
              email: user.email.isEmpty ? '—' : user.email,
              firstName: user.firstName,
              lastName: user.lastName,
            )
          : user,
      organizationName: orgName,
      organizationType: orgType,
      studentProfile: student,
      userProfile: userProfile,
      emailNotificationsEnabled: emailNotifications,
      dailyStudyHours: studyHours,
    );
  }

  @override
  Future<UserProfileSummary> updateProfile({
    required String displayName,
    String? phone,
  }) async {
    final session = await _requireSession();
    final envelope = await _api.patch(
      '/users/me/profile',
      body: {
        'display_name': displayName.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final profile = UserProfileSummary.fromJson(_asMap(envelope['data']));
    if (profile.id.isEmpty) {
      throw StateError('Profile update response missing user.');
    }
    return _withResolvedAvatar(session, profile);
  }

  @override
  Future<UserProfileSummary> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final session = await _requireSession();
    final current = await _loadUserProfile(session);
    final profileId = current?.id;
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Create your profile before uploading a photo.',
        statusCode: 0,
      );
    }

    final mediaFileId = await _avatarUploader.uploadAvatarBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      profileId: profileId,
    );

    final envelope = await _api.patch(
      '/users/me/profile',
      body: {'avatar_media_id': mediaFileId},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final profile = UserProfileSummary.fromJson(_asMap(envelope['data']));
    if (profile.id.isEmpty) {
      throw StateError('Avatar update response missing profile.');
    }
    return _withResolvedAvatar(
      session,
      profile.copyWith(avatarMediaId: mediaFileId),
    );
  }

  @override
  Future<UserProfileSummary> clearAvatar() async {
    final session = await _requireSession();
    final envelope = await _api.patch(
      '/users/me/profile',
      body: {'clear_avatar': true},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final profile = UserProfileSummary.fromJson(_asMap(envelope['data']));
    if (profile.id.isEmpty) {
      throw StateError('Avatar clear response missing profile.');
    }
    return profile.copyWith(clearAvatarUrl: true, clearAvatarMediaId: true);
  }

  @override
  Future<void> setEmailNotifications({
    required String studentProfileId,
    required bool enabled,
  }) async {
    final id = studentProfileId.trim();
    if (id.isEmpty) {
      throw StateError('Student profile is required.');
    }
    final session = await _requireSession();
    await _api.put(
      '/students/$id/settings/notifications.email',
      body: {
        'value': {
          'enabled': enabled,
          'email': enabled,
        },
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> setDailyStudyHours({
    required String studentProfileId,
    required double hours,
  }) async {
    final id = studentProfileId.trim();
    if (id.isEmpty) {
      throw StateError('Student profile is required.');
    }
    final session = await _requireSession();
    final clamped = hours.clamp(0, 16).toDouble();
    await _api.put(
      '/students/$id/preferences/daily_study_hours',
      body: {
        'value': {'hours': clamped},
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> signOut() async {
    final access = await _tokens.readAccessToken();
    if (access != null && access.isNotEmpty) {
      try {
        await _api.post(
          '/auth/logout',
          accessToken: access,
        );
      } catch (_) {
        // Still clear local session if the revoke call fails.
      }
    }
    await _tokens.clear();
    await _tenant.clear();
    MarketplaceAccessService.instance.reset();
  }

  Future<StudentProfileSummary?> _loadStudentProfile(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/students/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final profile = StudentProfileSummary.fromJson(_asMap(envelope['data']));
      return profile.id.isEmpty ? null : profile;
    } on ApiException catch (error) {
      if (_isWrongAppAccess(error)) {
        await _tokens.clear();
        await _tenant.clear();
        MarketplaceAccessService.instance.reset();
        AuthSessionEvents.notifyExpired();
        rethrow;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isWrongAppAccess(ApiException error) {
    if (error.statusCode == 403) return true;
    final code = (error.code ?? '').toUpperCase();
    return code.contains('FORBIDDEN') ||
        code.contains('NOT_A_STUDENT') ||
        code.contains('STUDENT_REQUIRED') ||
        code.contains('WRONG_ROLE');
  }

  Future<UserProfileSummary?> _loadUserProfile(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/users/me/profile',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final profile = UserProfileSummary.fromJson(_asMap(envelope['data']));
      if (profile.id.isEmpty) return null;
      return await _withResolvedAvatar(session, profile);
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<UserProfileSummary> _withResolvedAvatar(
    SessionContext session,
    UserProfileSummary profile,
  ) async {
    final existingUrl = profile.avatarUrl?.trim();
    if (existingUrl != null && existingUrl.isNotEmpty) return profile;

    final mediaId = profile.avatarMediaId?.trim();
    if (mediaId == null || mediaId.isEmpty) return profile;

    final resolved = await _resolveMediaDownloadUrl(session, mediaId);
    if (resolved == null) return profile;
    return profile.copyWith(avatarUrl: resolved);
  }

  Future<String?> _resolveMediaDownloadUrl(
    SessionContext session,
    String mediaFileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/media/files/$mediaFileId/download',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      return _nullableTrim(data['url']?.toString());
    } catch (_) {
      return null;
    }
  }

  String? _nullableTrim(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<List<Map<String, dynamic>>> _loadSettings(
    SessionContext session,
    String studentId,
  ) async {
    try {
      final envelope = await _api.get(
        '/students/$studentId/settings',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseList(envelope['data']);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadPreferences(
    SessionContext session,
    String studentId,
  ) async {
    try {
      final envelope = await _api.get(
        '/students/$studentId/preferences',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseList(envelope['data']);
    } catch (_) {
      return const [];
    }
  }

  static bool _emailEnabledFromSettings(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final key =
          row['setting_key']?.toString() ?? row['key']?.toString() ?? '';
      if (key != 'notifications.email') continue;
      final value = row['value'];
      if (value is Map) {
        final map = value.map((k, v) => MapEntry(k.toString(), v));
        if (map['email'] == false || map['enabled'] == false) return false;
        if (map['email'] == true || map['enabled'] == true) return true;
      }
      if (value == false) return false;
      if (value == true) return true;
    }
    return true;
  }

  static double? _hoursFromPreferences(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final key = row['preference_key']?.toString() ??
          row['key']?.toString() ??
          '';
      if (key != 'daily_study_hours') continue;
      final value = row['value'];
      if (value is Map) {
        final raw = value['hours'];
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw?.toString() ?? '');
      }
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }
    return null;
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  static List<Map<String, dynamic>> _parseList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final nested = map['items'] ?? map['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
    }
    return const [];
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
