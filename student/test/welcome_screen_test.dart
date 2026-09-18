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

  Future<void> pumpWelcome(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        onGenerateRoute: onGenerateRoute,
        home: const WelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('S-02 welcome onboarding shows slides and entry actions', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpWelcome(tester, const Size(390, 844));

    expect(find.textContaining('Your Preparation'), findsOneWidget);
    expect(find.textContaining('Companion'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.image(
        const AssetImage('assets/images/onboarding/hero_companion.png'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Practice with'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Mock Tests'), findsOneWidget);

    // Dot indicators jump to the matching page.
    await tester.tap(find.bySemanticsLabel('Onboarding page 1 of 3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your Preparation'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Onboarding page 3 of 3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Track Your'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('S-02 onboarding has no overflow across phone sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const sizes = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(375, 667),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
    ];

    for (final size in sizes) {
      await pumpWelcome(tester, size);

      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow/exception at $size',
      );
      expect(
        find.textContaining('Your Preparation'),
        findsOneWidget,
        reason: 'title missing at $size',
      );
      expect(
        find.textContaining('AI-powered feedback'),
        findsOneWidget,
        reason: 'description clipped at $size',
      );
      expect(find.text('Next'), findsOneWidget, reason: 'CTA missing at $size');
      expect(find.text('Skip'), findsOneWidget, reason: 'Skip missing at $size');
    }
  });
}
