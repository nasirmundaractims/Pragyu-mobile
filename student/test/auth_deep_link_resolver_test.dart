import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/features/auth/domain/auth_deep_link_resolver.dart';
import 'package:student_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:student_mobile/features/auth/presentation/screens/verify_email_screen.dart';

void main() {
  group('AuthDeepLinkResolver', () {
    test('resolves https reset-password with email + token', () {
      final target = AuthDeepLinkResolver.resolve(
        Uri.parse(
          'https://student.pragyu.com/reset-password'
          '?email=a%40b.com&token=tok-1&expires=1&signature=sig',
        ),
      );

      expect(target?.route, AppRoutes.resetPassword);
      final args = target!.arguments as ResetPasswordArgs;
      expect(args.email, 'a@b.com');
      expect(args.token, 'tok-1');
    });

    test('resolves https verify-email with id + token', () {
      final target = AuthDeepLinkResolver.resolve(
        Uri.parse(
          'https://pragyu.com/verify-email?id=user-9&token=ver-2&email=a%40b.com',
        ),
      );

      expect(target?.route, AppRoutes.verifyEmail);
      final args = target!.arguments as VerifyEmailArgs;
      expect(args.id, 'user-9');
      expect(args.token, 'ver-2');
      expect(args.email, 'a@b.com');
    });

    test('resolves custom scheme host form', () {
      final reset = AuthDeepLinkResolver.resolve(
        Uri.parse('pragyu://reset-password?email=a@b.com&token=t1'),
      );
      expect(reset?.route, AppRoutes.resetPassword);
      expect((reset!.arguments as ResetPasswordArgs).token, 't1');

      final verify = AuthDeepLinkResolver.resolve(
        Uri.parse('pragyu://verify-email?id=u1&token=t2'),
      );
      expect(verify?.route, AppRoutes.verifyEmail);
      expect((verify!.arguments as VerifyEmailArgs).id, 'u1');
    });

    test('resolves path-only URIs', () {
      final target = AuthDeepLinkResolver.resolve(
        Uri.parse('/reset-password?email=a@b.com&token=t'),
      );
      expect(target?.route, AppRoutes.resetPassword);
    });

    test('ignores unrelated paths', () {
      expect(
        AuthDeepLinkResolver.resolve(Uri.parse('https://pragyu.com/catalog')),
        isNull,
      );
      expect(
        AuthDeepLinkResolver.resolve(Uri.parse('pragyu://home')),
        isNull,
      );
    });

    test('buildAppLink creates custom-scheme URI', () {
      final uri = AuthDeepLinkResolver.buildAppLink(
        path: 'verify-email',
        query: {'id': 'u1', 'token': 't1', 'email': null},
      );
      expect(uri.scheme, 'pragyu');
      expect(uri.host, 'verify-email');
      expect(uri.queryParameters['id'], 'u1');
      expect(uri.queryParameters.containsKey('email'), isFalse);
    });
  });
}
