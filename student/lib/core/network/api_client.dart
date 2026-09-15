import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';

typedef JsonMap = Map<String, dynamic>;

/// Thin HTTP client for Pragyu `/api/v1` JSON envelope responses.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.instance.apiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

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

  Future<JsonMap> _send(
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

  JsonMap _decodeEnvelope(http.Response response) {
    JsonMap? decoded;
    if (response.body.isNotEmpty) {
      try {
        final dynamic raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = raw.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        decoded = null;
      }
    }

    final status = response.statusCode;
    final success = decoded?['success'] == true;
    final message = (decoded?['message'] as String?)?.trim();
    final code = decoded?['code'] as String?;
    final data = decoded?['data'];

    // Login MFA challenge is 202 with success:true.
    if (status >= 200 && status < 300 && success) {
      return {
        'statusCode': status,
        'message': message ?? '',
        'data': data,
        'code': code,
      };
    }

    final fieldErrors = <String, String>{};
    final errors = decoded?['errors'];
    if (errors is List) {
      for (final item in errors) {
        if (item is Map) {
          final field = item['field']?.toString();
          final errMessage = item['message']?.toString();
          if (field != null &&
              field.isNotEmpty &&
              errMessage != null &&
              errMessage.isNotEmpty) {
            fieldErrors[field] = errMessage;
          }
        }
      }
    }

    throw ApiException(
      message: (message != null && message.isNotEmpty)
          ? message
          : 'Request failed ($status).',
      statusCode: status,
      code: code,
      fieldErrors: fieldErrors,
      data: data is Map<String, dynamic>
          ? data
          : (data is Map
              ? data.map((k, v) => MapEntry(k.toString(), v))
              : null),
    );
  }

  static String _join(String base, String path) {
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }

  void close() => _http.close();
}
