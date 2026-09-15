import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/onboarding/data/memory_onboarding_store.dart';
import 'package:student_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';

class _FakeHome implements HomeGateway {
  @override
  Future<HomeSnapshot> loadHome() async {
    return const HomeSnapshot(
      user: AuthUser(id: '1', email: 'a@b.com', firstName: 'Alex'),
    );
  }

  @override
  Future<TodaySnapshot> loadToday() async {
    return TodaySnapshot(day: DateTime(2026, 9, 15));
  }
}

Route<dynamic> _routes(RouteSettings settings) {
  if (settings.name == AppRoutes.home) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => StudentShell(homeRepository: _FakeHome()),
    );
  }
  return onGenerateRoute(settings);
}

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
        onGenerateRoute: _routes,
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
    expect(find.textContaining('Here’s what’s next today.'), findsOneWidget);
  });

  testWidgets('S-06 skip marks complete and opens home', (tester) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: _routes,
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
    expect(find.textContaining('Here’s what’s next today.'), findsOneWidget);
  });

  testWidgets('S-06 skips slides when already completed', (tester) async {
    final store = MemoryOnboardingStore(completed: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: _routes,
        home: OnboardingScreen(onboardingStore: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsNothing);
    expect(find.textContaining('Here’s what’s next today.'), findsOneWidget);
  });
}
