import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_environment.dart';

/// Central app configuration loaded from dart-define + env asset files.
///
/// Secrets must never be hard-coded. Prefer `--dart-define=API_BASE_URL=...`
/// in CI/CD for production overrides.
class AppConfig {
  AppConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    this.studentWebBaseUrl,
    this.supportEmail,
    this.privacyUrl,
    this.termsUrl,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String appName;
  /// Optional student-web origin for hosted Razorpay checkout handoff.
  final String? studentWebBaseUrl;
  final String? supportEmail;
  final String? privacyUrl;
  final String? termsUrl;

  static AppConfig? _instance;

  static AppConfig get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AppConfig has not been initialized. Call bootstrap first.');
    }
    return value;
  }

  static Future<AppConfig> load() async {
    const envFromDefine = String.fromEnvironment('APP_ENV', defaultValue: '');
    const apiFromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const nameFromDefine = String.fromEnvironment('APP_NAME', defaultValue: '');
    const webFromDefine =
        String.fromEnvironment('STUDENT_WEB_BASE_URL', defaultValue: '');
    const supportFromDefine =
        String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '');
    const privacyFromDefine =
        String.fromEnvironment('PRIVACY_URL', defaultValue: '');
    const termsFromDefine =
        String.fromEnvironment('TERMS_URL', defaultValue: '');

    final environment = AppEnvironment.fromString(
      envFromDefine.isEmpty ? null : envFromDefine,
    );

    final fileValues = await _loadEnvAsset(environment.envFileName);
    final webBase = webFromDefine.isNotEmpty
        ? webFromDefine
        : fileValues['STUDENT_WEB_BASE_URL'];

    final config = AppConfig._(
      environment: environment,
      apiBaseUrl: apiFromDefine.isNotEmpty
          ? apiFromDefine
          : (fileValues['API_BASE_URL'] ??
              (environment.isProduction
                  ? ''
                  : 'http://10.0.2.2:8000/api/v1')),
      appName: nameFromDefine.isNotEmpty
          ? nameFromDefine
          : (fileValues['APP_NAME'] ?? 'Pragyu'),
      studentWebBaseUrl: _nullableUrl(webBase),
      supportEmail: _nullableTrim(
        supportFromDefine.isNotEmpty
            ? supportFromDefine
            : fileValues['SUPPORT_EMAIL'],
      ),
      privacyUrl: _nullableUrl(
        privacyFromDefine.isNotEmpty
            ? privacyFromDefine
            : fileValues['PRIVACY_URL'],
      ),
      termsUrl: _nullableUrl(
        termsFromDefine.isNotEmpty ? termsFromDefine : fileValues['TERMS_URL'],
      ),
    );

    if (config.apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is required for production. Pass '
        '--dart-define=API_BASE_URL=https://… or ship assets/env/.env.production.',
      );
    }

    _instance = config;

    if (kDebugMode) {
      debugPrint(
        'AppConfig loaded env=${config.environment.name} api=${config.apiBaseUrl}',
      );
    }

    return config;
  }

  static Future<Map<String, String>> _loadEnvAsset(String fileName) async {
    try {
      final raw = await rootBundle.loadString('assets/env/$fileName');
      final map = <String, String>{};
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final index = trimmed.indexOf('=');
        if (index <= 0) continue;
        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        map[key] = value;
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  static String? _nullableTrim(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? _nullableUrl(String? raw) {
    final value = _nullableTrim(raw);
    if (value == null) return null;
    return value.replaceAll(RegExp(r'/+$'), '');
  }
}
