import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';

void main() {
  testWidgets('StudentSectionHeader renders title and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StudentSectionHeader(
            title: 'Upcoming',
            actionLabel: 'See All',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('See All'), findsOneWidget);
    await tester.tap(find.text('See All'));
    expect(tapped, isTrue);
  });

  testWidgets('AppEmptyState shows CTA', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppEmptyState(
            title: 'Nothing here',
            message: 'Try again later.',
            actionLabel: 'Browse',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Browse'));
    expect(tapped, isTrue);
  });

  testWidgets('AppErrorState shows title and retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppErrorState(
            title: 'Load failed',
            message: 'Network error',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Load failed'), findsOneWidget);
    expect(find.text('Network error'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('AppLoadingState paints spinner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLoadingState()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('StudentHubPage shows header title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const StudentHubPage(
          title: 'Kit Demo',
          body: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Kit Demo'), findsOneWidget);
  });
}
