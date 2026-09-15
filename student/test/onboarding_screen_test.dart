import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/onboarding/data/memory_onboarding_store.dart';
import 'package:student_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-06 shows Learn / Tests / Alerts tips', (tester) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: onGenerateRoute,
        home: OnboardingScreen(
          onboardingStore: store,
          forceShow: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Tests'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(store.completed, isTrue);
    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('S-10 Home'), findsOneWidget);
  });

  testWidgets('S-06 skip marks complete and opens home stub', (tester) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: onGenerateRoute,
        home: OnboardingScreen(
          onboardingStore: store,
          forceShow: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(store.completed, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('S-06 skips slides when already completed', (tester) async {
    final store = MemoryOnboardingStore(completed: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: onGenerateRoute,
        home: OnboardingScreen(onboardingStore: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learn'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
