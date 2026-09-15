/// Supported runtime environments for Pragyu Student.
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromString(String? value) {
    switch ((value ?? 'development').toLowerCase().trim()) {
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      default:
        return AppEnvironment.development;
    }
  }

  String get envFileName => switch (this) {
        AppEnvironment.development => '.env.development',
        AppEnvironment.staging => '.env.staging',
        AppEnvironment.production => '.env.production.example',
      };

  bool get isProduction => this == AppEnvironment.production;
}
