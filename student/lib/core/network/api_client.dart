import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/auth_session_events.dart';
import 'package:student_mobile/core/storage/platform_stores.dart';
import 'package:student_mobile/features/auth/data/token_store.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
import 'package:student_mobile/features/organization/data/tenant_store.dart';

typedef JsonMap = Map<String, dynamic>;

/// Thin HTTP client for Pragyu `/api/v1` JSON envelope responses.
///
/// On `401` / `AUTH_002`, tries one refresh via stored refresh token, then retries.
/// If refresh fails, clears tokens and notifies [AuthSessionEvents].
class ApiClient {
  final http.Client _http;
  final String _baseUrl;
  final TokenStore _tokens;
  final TenantStore _tenant;

  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    TokenStore? tokenStore,
    TenantStore? tenantStore,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.instance.apiBaseUrl,
        _tokens = tokenStore ?? createTokenStore(),
        _tenant = tenantStore ?? createTenantStore();

  static Future<String?>? _refreshInFlight;

  Future<JsonMap> post(
    String path, {
    JsonMap? body,
    String? accessToken,
    String? organizationId,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      accessToken: accessToken,
      organizationId: organizationId,
    );
  }

  Future<JsonMap> get(
    String path, {
    Map<String, String>? query,
    String? accessToken,
    String? organizationId,
  }) {
    return _send(
      'GET',
      path,
      query: query,
      accessToken: accessToken,
      organizationId: organizationId,
    );
  }

  Future<JsonMap> patch(
    String path, {
    JsonMap? body,
    String? accessToken,
    String? organizationId,
  }) {
    return _send(
      'PATCH',
      path,
      body: body,
      accessToken: accessToken,
      organizationId: organizationId,
    );
  }

  Future<JsonMap> put(
    String path, {
    JsonMap? body,
    String? accessToken,
    String? organizationId,
  }) {
    return _send(
      'PUT',
      path,
      body: body,
      accessToken: accessToken,
      organizationId: organizationId,
    );
  }

  Future<JsonMap> delete(
    String path, {
    String? accessToken,
    String? organizationId,
  }) {
    return _send(
      'DELETE',
      path,
      accessToken: accessToken,
      organizationId: organizationId,
    );
  }

  Future<JsonMap> _send(
    String method,
    String path, {
    JsonMap? body,
    Map<String, String>? query,
    String? accessToken,
    String? organizationId,
    bool allowRefresh = true,
  }) async {
    try {
      return await _sendOnce(
        method,
        path,
        body: body,
        query: query,
        accessToken: accessToken,
        organizationId: organizationId,
      );
    } on ApiException catch (error) {
      if (!allowRefresh ||
          !error.isUnauthorized ||
          _isAuthBootstrapPath(path)) {
        rethrow;
      }

      final refreshed = await _refreshAccessToken();
      if (refreshed == null || refreshed.isEmpty) {
        await _tokens.clear();
        await _tenant.clear();
        MarketplaceAccessService.instance.reset();
        AuthSessionEvents.notifyExpired();
        rethrow;
      }

      return _sendOnce(
        method,
        path,
        body: body,
        query: query,
        accessToken: refreshed,
        organizationId: organizationId,
      );
    }
  }

  Future<JsonMap> _sendOnce(
    String method,
    String path, {
    JsonMap? body,
    Map<String, String>? query,
    String? accessToken,
    String? organizationId,
  }) async {
    final uri = Uri.parse(_join(_baseUrl, path)).replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
      if (organizationId != null && organizationId.isNotEmpty)
        'X-Organization-Id': organizationId,
    };

    late http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await _http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'GET':
          response = await _http.get(uri, headers: headers);
        case 'PATCH':
          response = await _http.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'PUT':
          response = await _http.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'DELETE':
          response = await _http.delete(uri, headers: headers);
        default:
          throw ApiException(
            message: 'Unsupported HTTP method: $method',
            statusCode: 0,
          );
      }
    } on http.ClientException catch (error) {
      throw ApiException(
        message: 'Unable to reach Pragyu. Check your connection and try again.',
        statusCode: 0,
        cause: error,
      );
    }

    return _decodeEnvelope(response);
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight;
    }

    final completer = Completer<String?>();
    _refreshInFlight = completer.future;
    try {
      final refresh = await _tokens.readRefreshToken();
      final userJson = await _tokens.readUserJson();
      if (refresh == null || refresh.isEmpty) {
        completer.complete(null);
        return null;
      }

      final envelope = await _send(
        'POST',
        '/auth/refresh',
        body: {
          'refresh_token': refresh,
          'device_name': 'pragyu-student-mobile',
        },
        allowRefresh: false,
      );

      final data = envelope['data'];
      final dataMap = data is Map
          ? data.map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{};
      final tokenRaw = dataMap['token'];
      final tokenMap = tokenRaw is Map
          ? tokenRaw.map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{};
      final access = tokenMap['access_token']?.toString() ?? '';
      final nextRefresh = tokenMap['refresh_token']?.toString() ?? refresh;
      if (access.isEmpty) {
        completer.complete(null);
        return null;
      }

      await _tokens.saveSession(
        accessToken: access,
        refreshToken: nextRefresh,
        userJson: userJson ?? '{}',
      );
      completer.complete(access);
      return access;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _refreshInFlight = null;
    }
  }

  static bool _isAuthBootstrapPath(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/auth/login') ||
        normalized.contains('/auth/refresh') ||
        normalized.contains('/auth/register') ||
        normalized.contains('/auth/forgot-password');
  }

  JsonMap _decodeEnvelope(http.Response response) {
    JsonMap? decoded;
    Object? bareList;
    if (response.body.isNotEmpty) {
      try {
        final dynamic raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = raw.map((key, value) => MapEntry(key.toString(), value));
        } else if (raw is List) {
          bareList = raw;
        }
      } catch (_) {
        decoded = null;
      }
    }

    final status = response.statusCode;
    final hasSuccessFlag = decoded != null && decoded.containsKey('success');
    final successFlag = decoded?['success'] == true;
    final message = (decoded?['message'] as String?)?.trim();
    final code = decoded?['code'] as String?;
    final data = decoded?['data'];

    if (status >= 200 && status < 300) {
      if (hasSuccessFlag && !successFlag) {
        throw ApiException(
          message: (message != null && message.isNotEmpty)
              ? message
              : 'Request failed ($status).',
          statusCode: status,
          code: code,
          fieldErrors: _fieldErrors(decoded),
          data: _asDataMap(data),
        );
      }

      return {
        'statusCode': status,
        'message': message ?? '',
        'data': bareList ?? data ?? decoded?['items'] ?? decoded,
        'code': code,
      };
    }

    throw ApiException(
      message: (message != null && message.isNotEmpty)
          ? message
          : 'Request failed ($status).',
      statusCode: status,
      code: code,
      fieldErrors: _fieldErrors(decoded),
      data: _asDataMap(data),
    );
  }

  static Map<String, String> _fieldErrors(JsonMap? decoded) {
    final errors = decoded?['errors'];
    if (errors is! Map) return const {};
    final out = <String, String>{};
    errors.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        out[key.toString()] = value.first.toString();
      } else if (value != null) {
        out[key.toString()] = value.toString();
      }
    });
    return out;
  }

  static JsonMap? _asDataMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static String _join(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }
}
