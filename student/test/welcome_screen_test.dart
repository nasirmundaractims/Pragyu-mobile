import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-02 welcome shows entry actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        onGenerateRoute: onGenerateRoute,
        home: const WelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pragyu'), findsOneWidget);
    expect(
      find.textContaining('Your classes, tests, and learning'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back. Use your student email and password.'),
        findsOneWidget);
  });
}
