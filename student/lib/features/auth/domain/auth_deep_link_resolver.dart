import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:student_mobile/features/auth/presentation/screens/verify_email_screen.dart';

/// Resolved navigation target for an auth email / app link.
class AuthDeepLinkTarget {
  const AuthDeepLinkTarget({
    required this.route,
    required this.arguments,
  });

  final String route;
  final Object arguments;
}

/// Maps reset-password / verify-email URIs to [AppRoutes] + args.
///
/// Supports:
/// - `https://…/reset-password?email=&token=`
/// - `https://…/verify-email?id=&token=`
/// - Custom scheme `pragyu://reset-password?…` / `pragyu://verify-email?…`
/// - Path-style custom scheme `pragyu:///reset-password?…`
abstract final class AuthDeepLinkResolver {
  static const customScheme = 'pragyu';

  static AuthDeepLinkTarget? resolve(Uri? uri) {
    if (uri == null) return null;

    final path = _authPath(uri);
    if (path == null) return null;

    final params = uri.queryParameters;
    if (path == 'reset-password' || path == 'reset_password') {
      return AuthDeepLinkTarget(
        route: AppRoutes.resetPassword,
        arguments: ResetPasswordArgs(
          email: _nonEmpty(params['email']),
          token: _nonEmpty(params['token']),
        ),
      );
    }

    if (path == 'verify-email' || path == 'verify_email') {
      return AuthDeepLinkTarget(
        route: AppRoutes.verifyEmail,
        arguments: VerifyEmailArgs(
          email: _nonEmpty(params['email']),
          id: _nonEmpty(params['id']),
          token: _nonEmpty(params['token']),
        ),
      );
    }

    return null;
  }

  /// Builds a custom-scheme URI the OS can hand to the Student app.
  static Uri buildAppLink({
    required String path,
    Map<String, String?> query = const {},
  }) {
    final cleaned = path.replaceAll(RegExp(r'^/+|/+$'), '');
    final filtered = <String, String>{};
    query.forEach((key, value) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) filtered[key] = v;
    });
    return Uri(
      scheme: customScheme,
      host: cleaned,
      queryParameters: filtered.isEmpty ? null : filtered,
    );
  }

  static String? _authPath(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == customScheme) {
      final host = uri.host.trim().toLowerCase();
      if (host.isNotEmpty) return host;
      return _lastSegment(uri.path);
    }

    // https/http web links, or path-only URIs (`/reset-password`).
    if (scheme == 'http' || scheme == 'https' || scheme.isEmpty) {
      return _lastSegment(uri.path);
    }

    return null;
  }

  static String? _lastSegment(String path) {
    final cleaned = path.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty || cleaned == '/') return null;
    final parts = cleaned.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.last;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
