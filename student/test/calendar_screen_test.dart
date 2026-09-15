import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/calendar/data/calendar_repository.dart';
import 'package:student_mobile/features/calendar/domain/calendar_models.dart';
import 'package:student_mobile/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';

class _FakeCalendar implements CalendarGateway {
  _FakeCalendar(this.snapshot);

  final CalendarSnapshot snapshot;

  @override
  Future<CalendarSnapshot> loadCalendar({
    int horizonDays = 14,
    DateTime? now,
  }) async {
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-30 groups events by day with filters', (tester) async {
    final now = DateTime(2026, 9, 15, 10);
    final today = DateTime(now.year, now.month, now.day, 14);
    final tomorrow = today.add(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CalendarScreen(
          calendarRepository: _FakeCalendar(
            CalendarSnapshot.fromEvents([
              CalendarEvent(
                id: 'live-1',
                kind: CalendarEventKind.live,
                title: 'Polity Live',
                startsAt: today,
                sourceId: 'lec-1',
                subtitle: 'Polity',
                isLiveNow: true,
              ),
              CalendarEvent(
                id: 'test-1',
                kind: CalendarEventKind.test,
                title: 'GS Mock',
                startsAt: tomorrow,
                sourceId: 'a1',
                subtitle: 'Due',
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Polity Live'), findsOneWidget);
    expect(find.text('GS Mock'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Tests'), findsOneWidget);

    await tester.tap(find.text('Tests'));
    await tester.pumpAndSettle();

    expect(find.text('GS Mock'), findsOneWidget);
    expect(find.text('Polity Live'), findsNothing);
  });

  testWidgets('S-30 empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CalendarScreen(
          calendarRepository: _FakeCalendar(const CalendarSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing upcoming in this window.'), findsOneWidget);
  });

  testWidgets('S-30 live tap opens lobby route', (tester) async {
    Object? pushedArgs;
    final now = DateTime(2026, 9, 15, 14);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CalendarScreen(
          calendarRepository: _FakeCalendar(
            CalendarSnapshot.fromEvents([
              CalendarEvent(
                id: 'live-1',
                kind: CalendarEventKind.live,
                title: 'Polity Live',
                startsAt: now,
                sourceId: 'lec-1',
                isLiveNow: true,
              ),
            ]),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.liveLobby) {
            pushedArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Live lobby')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Polity Live'));
    await tester.pumpAndSettle();

    expect(find.text('Live lobby'), findsOneWidget);
    expect(pushedArgs, isA<LiveLobbyArgs>());
    expect((pushedArgs! as LiveLobbyArgs).lectureId, 'lec-1');
  });

  testWidgets('S-30 test tap stubs S-41', (tester) async {
    final now = DateTime(2026, 9, 16, 9);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CalendarScreen(
          calendarRepository: _FakeCalendar(
            CalendarSnapshot.fromEvents([
              CalendarEvent(
                id: 'test-1',
                kind: CalendarEventKind.test,
                title: 'GS Mock',
                startsAt: now,
                sourceId: 'a1',
                subtitle: 'Due',
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GS Mock'));
    await tester.pump();

    expect(find.textContaining('S-41'), findsOneWidget);
  });

  test('CalendarSnapshot.fromEvents groups by day', () {
    final day1 = DateTime(2026, 9, 15, 10);
    final day2 = DateTime(2026, 9, 16, 11);
    final snapshot = CalendarSnapshot.fromEvents([
      CalendarEvent(
        id: 'b',
        kind: CalendarEventKind.test,
        title: 'B',
        startsAt: day2,
        sourceId: '2',
      ),
      CalendarEvent(
        id: 'a',
        kind: CalendarEventKind.live,
        title: 'A',
        startsAt: day1,
        sourceId: '1',
      ),
    ]);

    expect(snapshot.days.length, 2);
    expect(snapshot.days.first.events.single.title, 'A');
    expect(snapshot.days.last.events.single.title, 'B');
  });

  test('assessmentWhen prefers deadline then closes', () {
    expect(
      assessmentWhen({
        'closes_at': '2026-09-20T10:00:00Z',
        'scheduled_at': '2026-09-18T10:00:00Z',
      })?.toUtc().toIso8601String(),
      '2026-09-20T10:00:00.000Z',
    );
    expect(
      assessmentWhen({
        'deadline_at': '2026-09-19T12:00:00Z',
        'closes_at': '2026-09-20T10:00:00Z',
      })?.toUtc().toIso8601String(),
      '2026-09-19T12:00:00.000Z',
    );
  });
}
