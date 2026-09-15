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
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String appName;

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

    final environment = AppEnvironment.fromString(
      envFromDefine.isEmpty ? null : envFromDefine,
    );

    final fileValues = await _loadEnvAsset(environment.envFileName);

    final config = AppConfig._(
      environment: environment,
      apiBaseUrl: apiFromDefine.isNotEmpty
          ? apiFromDefine
          : (fileValues['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1'),
      appName: nameFromDefine.isNotEmpty
          ? nameFromDefine
          : (fileValues['APP_NAME'] ?? 'Pragyu'),
    );

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
}
