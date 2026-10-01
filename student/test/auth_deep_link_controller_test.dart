import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/features/auth/domain/auth_deep_link_resolver.dart';
import 'package:student_mobile/features/auth/presentation/auth_deep_link_controller.dart';
import 'package:student_mobile/features/auth/presentation/screens/reset_password_screen.dart';

void main() {
  tearDown(() {
    AuthDeepLinkController.debugSetInstance(null);
  });

  test('stores pending target until navigation is ready', () async {
    final controller = AuthDeepLinkController(
      uriStream: const Stream<Uri>.empty(),
    );
    await controller.start();

    controller.handleUri(
      Uri.parse('pragyu://reset-password?email=a@b.com&token=tok'),
    );

    expect(controller.debugPending?.route, AppRoutes.resetPassword);
    final pending = controller.consumePending();
    expect(pending?.route, AppRoutes.resetPassword);
    expect((pending!.arguments as ResetPasswordArgs).token, 'tok');
    expect(controller.debugPending, isNull);

    await controller.dispose();
  });
}
