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
    expect(find.textContaining('Your Learning'), findsOneWidget);
    expect(find.text('Smarter'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.ensureVisible(find.text('I already have an account'));
    await tester.tap(find.text('I already have an account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Sign in'), findsWidgets);
    expect(
      find.textContaining('Welcome'),
      findsOneWidget,
    );
  });
}
