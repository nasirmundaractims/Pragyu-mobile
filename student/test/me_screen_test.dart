import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/alerts/domain/alerts_models.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/me/data/me_repository.dart';
import 'package:student_mobile/features/me/domain/me_models.dart';
import 'package:student_mobile/features/me/presentation/screens/me_screen.dart';

class _FakeMe implements MeGateway {
  _FakeMe(this.snapshot);

  MeSnapshot snapshot;
  bool? lastEmailEnabled;
  double? lastHours;
  String? lastDisplayName;
  String? lastPhone;
  int signOutCalls = 0;

  @override
  Future<MeSnapshot> loadMe() async => snapshot;

  @override
  Future<UserProfileSummary> updateProfile({
    required String displayName,
    String? phone,
  }) async {
    lastDisplayName = displayName;
    lastPhone = phone;
    final updated = UserProfileSummary(
      id: snapshot.userProfile?.id ?? 'up1',
      displayName: displayName,
      phone: phone,
      locale: snapshot.userProfile?.locale,
      timezone: snapshot.userProfile?.timezone,
    );
    snapshot = snapshot.copyWith(userProfile: updated);
    return updated;
  }

  @override
  Future<void> setEmailNotifications({
    required String studentProfileId,
    required bool enabled,
  }) async {
    lastEmailEnabled = enabled;
    snapshot = snapshot.copyWith(emailNotificationsEnabled: enabled);
  }

  @override
  Future<void> setDailyStudyHours({
    required String studentProfileId,
    required double hours,
  }) async {
    lastHours = hours;
    snapshot = snapshot.copyWith(dailyStudyHours: hours);
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

class _FakeAlerts implements AlertsGateway {
  @override
  Future<AlertsSnapshot> loadAlerts({int page = 1}) async => const AlertsSnapshot();

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> markRead(AlertItem item) async {}

  @override
  Future<void> markAllRead() async {}
}

class _FakeHome implements HomeGateway {
  @override
  Future<HomeSnapshot> loadHome() async {
    return const HomeSnapshot(
      user: AuthUser(id: '1', email: 'a@b.com', firstName: 'Alex'),
      progress: HomeProgressSummary(
        coursesEnrolled: 2,
        testsAttempted: 3,
        overallPercent: 80,
      ),
    );
  }

  @override
  Future<TodaySnapshot> loadToday() async {
    return TodaySnapshot(day: DateTime(2026, 9, 15));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MeSnapshot sample() {
    return const MeSnapshot(
      user: AuthUser(
        id: 'u1',
        email: 'alex@pragyu.test',
        firstName: 'Alex',
        lastName: 'Student',
      ),
      organizationName: 'Pragyu Demo Institute',
      organizationType: 'academy',
      studentProfile: StudentProfileSummary(
        id: 'sp1',
        studentCode: 'STU-101',
        status: 'active',
      ),
      userProfile: UserProfileSummary(
        id: 'up1',
        displayName: 'Alex Student',
      ),
      emailNotificationsEnabled: true,
      dailyStudyHours: 2,
    );
  }

  testWidgets('S-70 shows profile and opens notification preferences', (tester) async {
    final fake = _FakeMe(sample());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.notificationPreferences) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                body: Text('Notification preferences page'),
              ),
            );
          }
          return null;
        },
        home: MeScreen(
          meRepository: fake,
          homeRepository: _FakeHome(),
          alertsRepository: _FakeAlerts(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsOneWidget);
    expect(find.text('S-70 is next'), findsNothing);
    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('alex@pragyu.test'), findsOneWidget);
    expect(find.text('Pragyu Demo Institute'), findsWidgets);
    expect(find.textContaining('STU-101'), findsOneWidget);
    expect(find.text('Learning'), findsOneWidget);
    expect(find.text('Exams'), findsOneWidget);
    expect(find.text('Organisation'), findsWidgets);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Notification preferences'), findsOneWidget);
    expect(find.text('Help & About'), findsOneWidget);
    expect(find.text('About Pragyu'), findsNothing);
    expect(find.text('Switch organisation'), findsOneWidget);
    expect(find.text('Exam Series'), findsOneWidget);
    expect(find.text('Exam Workspace'), findsNothing);
    expect(find.text('Logout'), findsWidgets);

    await tester.ensureVisible(find.text('Notification preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notification preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Notification preferences page'), findsOneWidget);
  });

  testWidgets('S-70 individual workspace hides attendance', (tester) async {
    final fake = _FakeMe(
      const MeSnapshot(
        user: AuthUser(
          id: 'u1',
          email: 'solo@pragyu.test',
          firstName: 'Solo',
        ),
        organizationName: 'My Learning',
        organizationType: 'individual',
        userProfile: UserProfileSummary(
          id: 'up1',
          displayName: 'Solo Learner',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MeScreen(
          meRepository: fake,
          homeRepository: _FakeHome(),
          alertsRepository: _FakeAlerts(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Individual'), findsWidgets);
    expect(find.text('Attendance'), findsNothing);
    expect(find.text('Join organisation'), findsOneWidget);
  });

  testWidgets('S-70 edits display name and phone', (tester) async {
    final fake = _FakeMe(sample());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MeScreen(
          meRepository: fake,
          homeRepository: _FakeHome(),
          alertsRepository: _FakeAlerts(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Alex Updated');
    await tester.enterText(fields.at(1), '9876543210');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fake.lastDisplayName, 'Alex Updated');
    expect(fake.lastPhone, '9876543210');
    expect(find.text('Alex Updated'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
  });

  testWidgets('S-70 logout confirms and navigates to sign in', (tester) async {
    final fake = _FakeMe(sample());
    Object? loggedOutRoute;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MeScreen(
          meRepository: fake,
          homeRepository: _FakeHome(),
          alertsRepository: _FakeAlerts(),
        ),
        onGenerateRoute: (settings) {
          loggedOutRoute = settings.name;
          if (settings.name == AppRoutes.signIn) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Sign in screen')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    final logout = find.widgetWithText(OutlinedButton, 'Logout');
    await tester.scrollUntilVisible(
      logout,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(find.text('Logout?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(fake.signOutCalls, 1);
    expect(find.text('Sign in screen'), findsOneWidget);
    expect(loggedOutRoute, AppRoutes.signIn);
  });

  testWidgets('S-70 Me tab shows profile in shell', (tester) async {
    final fake = _FakeMe(sample());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(
          initialIndex: 4,
          homeRepository: _FakeHome(),
          meRepository: fake,
          alertsRepository: _FakeAlerts(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsWidgets);
    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('S-70 is next'), findsNothing);
  });
}
