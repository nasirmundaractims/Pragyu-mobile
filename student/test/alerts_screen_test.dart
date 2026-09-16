import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/alerts/domain/alerts_models.dart';
import 'package:student_mobile/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';

class _FakeAlerts implements AlertsGateway {
  _FakeAlerts(this.snapshot);

  AlertsSnapshot snapshot;
  final List<String> markedIds = [];
  int markAllCalls = 0;
  int? lastUnreadReported;

  @override
  Future<AlertsSnapshot> loadAlerts() async => snapshot;

  @override
  Future<int> unreadCount() async => snapshot.unreadCount;

  @override
  Future<void> markRead(AlertItem item) async {
    markedIds.add(item.id);
    snapshot = snapshot.markItemRead(item.id);
  }

  @override
  Future<void> markAllRead() async {
    markAllCalls += 1;
    snapshot = snapshot.markAllRead();
  }
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AlertsSnapshot sampleSnapshot({DateTime? now}) {
    final clock = now ?? DateTime.now();
    return AlertsSnapshot(
      unreadCount: 2,
      items: [
        AlertItem(
          id: 'n1',
          source: AlertSource.notification,
          title: 'Evaluation complete',
          body: 'Your Polity quiz feedback is ready.',
          category: AlertCategory.evaluation,
          isRead: false,
          createdAt: clock,
        ),
        AlertItem(
          id: 'i1',
          source: AlertSource.inbox,
          title: 'Academy announcement',
          body: 'Live class moved to 6 PM.',
          category: AlertCategory.messages,
          isRead: false,
          createdAt: clock.subtract(const Duration(days: 1)),
        ),
        AlertItem(
          id: 'n2',
          source: AlertSource.notification,
          title: 'Lesson published',
          body: 'Module 3 notes are live.',
          category: AlertCategory.learning,
          isRead: true,
          createdAt: clock.subtract(const Duration(days: 3)),
        ),
      ],
    );
  }

  testWidgets('S-50 lists alerts by day and marks one read', (tester) async {
    final fake = _FakeAlerts(sampleSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AlertsScreen(
          alertsRepository: fake,
          onUnreadChanged: (count) => fake.lastUnreadReported = count,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('S-50 is next'), findsNothing);
    expect(find.text('2 unread · grouped by day'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Evaluation complete'), findsOneWidget);
    expect(find.text('Evaluation'), findsWidgets);
    expect(find.text('Academy announcement'), findsOneWidget);

    await tester.tap(find.text('Mark read').first);
    await tester.pumpAndSettle();

    expect(fake.markedIds, contains('n1'));
    expect(fake.lastUnreadReported, 1);
    expect(find.text('1 unread · grouped by day'), findsOneWidget);
  });

  testWidgets('S-50 mark all read clears unread', (tester) async {
    final fake = _FakeAlerts(sampleSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AlertsScreen(alertsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(fake.markAllCalls, 1);
    expect(find.text('All caught up · grouped by day'), findsOneWidget);
    expect(find.text('Unread'), findsNothing);
  });

  testWidgets('S-50 empty state', (tester) async {
    final fake = _FakeAlerts(const AlertsSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AlertsScreen(alertsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('S-50 Alerts tab shows inbox in shell', (tester) async {
    final fake = _FakeAlerts(sampleSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(
          initialIndex: 3,
          homeRepository: _FakeHome(),
          alertsRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alerts'), findsWidgets);
    expect(find.text('Evaluation complete'), findsOneWidget);
    expect(find.text('S-50 is next'), findsNothing);
  });
}
