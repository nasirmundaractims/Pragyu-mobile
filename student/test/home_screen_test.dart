import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/home/presentation/screens/today_detail_screen.dart';

class _FakeHome implements HomeGateway {
  _FakeHome({
    required this.home,
    TodaySnapshot? today,
  }) : today = today ?? TodaySnapshot(day: DateTime(2026, 9, 15));

  final HomeSnapshot home;
  final TodaySnapshot today;

  @override
  Future<HomeSnapshot> loadHome() async => home;

  @override
  Future<TodaySnapshot> loadToday() async => today;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-10 home shows greeting, schedule, progress, shortcuts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _FakeHome(
      home: HomeSnapshot(
        user: const AuthUser(
          id: '1',
          email: 'alex@example.com',
          firstName: 'Alex',
        ),
        nextLecture: const HomeLecture(
          id: 'lec-1',
          title: 'Live Polity Doubt Session',
          subjectName: 'Polity',
          sessionStatus: 'live',
        ),
        dueAssessments: const [
          HomeAssessment(
            id: 'a1',
            title: 'Weekly Quiz 3',
            due: DueState(
              urgency: DueUrgency.dueToday,
              label: 'Due today',
            ),
          ),
        ],
        unreadCount: 3,
        continueLearning: const HomeContinueItem(
          courseId: 'c1',
          title: 'Indian Constitution and Governance',
          subjectTag: 'Polity',
          progressPercent: 60,
        ),
        progress: const HomeProgressSummary(
          overallPercent: 65,
          coursesEnrolled: 12,
          testsAttempted: 28,
        ),
        upcomingLectures: const [
          HomeLecture(
            id: 'lec-1',
            title: 'Live Polity Doubt Session',
            sessionStatus: 'live',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(homeRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Alex'), findsOneWidget);
    expect(find.text('Continue Learning'), findsWidgets);
    expect(find.text('Indian Constitution and Governance'), findsOneWidget);
    expect(find.text('Live Polity Doubt Session'), findsOneWidget);
    expect(find.text('Weekly Quiz 3'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('AI Mentor'), findsOneWidget);
    expect(find.text('Your Goal'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('S-10 empty schedule message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(
          homeRepository: _FakeHome(
            home: const HomeSnapshot(
              user: AuthUser(id: '1', email: 'a@b.com', firstName: 'Sam'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No upcoming classes or tests right now.'),
      findsOneWidget,
    );
  });

  testWidgets('S-10 opens S-11 today detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _FakeHome(
      home: const HomeSnapshot(
        user: AuthUser(id: '1', email: 'a@b.com', firstName: 'Alex'),
      ),
      today: TodaySnapshot(
        day: DateTime(2026, 9, 15),
        classes: const [
          HomeLecture(
            id: 'lec-1',
            title: 'Morning Class',
            sessionStatus: 'live',
          ),
        ],
        deadlines: const [
          HomeAssessment(
            id: 'a1',
            title: 'Quiz due today',
            due: DueState(
              urgency: DueUrgency.dueToday,
              label: 'Due today',
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.todayDetail) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => TodayDetailScreen(homeRepository: fake),
            );
          }
          return onGenerateRoute(settings);
        },
        home: StudentShell(homeRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Upcoming Schedule'));
    await tester.tap(find.text('See All >').last);
    await tester.pumpAndSettle();

    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('Morning Class'), findsOneWidget);
    expect(find.text('Quiz due today'), findsOneWidget);
  });

  testWidgets('S-10 home has no overflow across phone sizes', (tester) async {
    const sizes = <Size>[
      Size(320, 700),
      Size(360, 740),
      Size(390, 844),
      Size(430, 932),
    ];

    final fake = _FakeHome(
      home: const HomeSnapshot(
        user: AuthUser(
          id: '1',
          email: 'alex@example.com',
          firstName: 'Alex',
          lastName: 'Munda',
        ),
        continueLearning: HomeContinueItem(
          courseId: 'c1',
          title: 'Indian Constitution',
          subjectTag: 'Polity',
          progressPercent: 68,
        ),
        progress: HomeProgressSummary(overallPercent: 64, coursesEnrolled: 3),
        upcomingLectures: [
          HomeLecture(
            id: 'lec-1',
            title: 'Current Affairs',
            sessionStatus: 'live',
          ),
        ],
        unreadCount: 3,
      ),
    );

    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StudentShell(homeRepository: fake),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.textContaining('Alex'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'scrolled $size');
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  test('deriveDueState marks overdue and due today', () {
    final now = DateTime(2026, 9, 15, 12);
    final overdue = deriveDueState(
      DateTime(2026, 9, 14).toIso8601String(),
      now: now,
    );
    expect(overdue.urgency, DueUrgency.overdue);

    final dueToday = deriveDueState(
      DateTime(2026, 9, 15, 18).toIso8601String(),
      now: now,
    );
    expect(dueToday.urgency, DueUrgency.dueToday);
  });
}
