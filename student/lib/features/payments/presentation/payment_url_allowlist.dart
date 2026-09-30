import 'package:student_mobile/core/config/app_config.dart';

/// Returns true when [uri] targets the API host or student-web handoff host.
bool isAllowedPaymentHandoffUri(Uri uri) {
  if (!uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;

  final allowed = <String>{};
  final api = Uri.tryParse(AppConfig.instance.apiBaseUrl);
  if (api != null && api.host.isNotEmpty) {
    allowed.add(api.host.toLowerCase());
  }
  final web = AppConfig.instance.studentWebBaseUrl;
  if (web != null && web.isNotEmpty) {
    final webUri = Uri.tryParse(web);
    if (webUri != null && webUri.host.isNotEmpty) {
      allowed.add(webUri.host.toLowerCase());
    }
  }

  // Local / emulator development hosts.
  allowed.addAll({'10.0.2.2', 'localhost', '127.0.0.1'});

  if (allowed.isEmpty) return uri.scheme == 'https';
  return allowed.contains(host);
}
