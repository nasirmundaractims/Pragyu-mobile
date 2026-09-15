import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/today_detail_screen.dart';

class _FakeHome implements HomeGateway {
  _FakeHome(this.today);

  final TodaySnapshot today;

  @override
  Future<HomeSnapshot> loadHome() async {
    return const HomeSnapshot(
      user: AuthUser(id: '1', email: 'a@b.com', firstName: 'Alex'),
    );
  }

  @override
  Future<TodaySnapshot> loadToday() async => today;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-11 shows classes and deadlines', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TodayDetailScreen(
          homeRepository: _FakeHome(
            TodaySnapshot(
              day: DateTime(2026, 9, 15),
              classes: const [
                HomeLecture(
                  id: '1',
                  title: 'Physics Live',
                  sessionStatus: 'live',
                ),
              ],
              deadlines: const [
                HomeAssessment(
                  id: 'a1',
                  title: 'Assignment 2',
                  due: DueState(
                    urgency: DueUrgency.dueToday,
                    label: 'Due today',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('Physics Live'), findsOneWidget);
    expect(find.text('Deadlines'), findsOneWidget);
    expect(find.text('Assignment 2'), findsOneWidget);
  });

  testWidgets('S-11 empty states', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TodayDetailScreen(
          homeRepository: _FakeHome(
            TodaySnapshot(day: DateTime(2026, 9, 15)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing scheduled for today.'), findsOneWidget);
    expect(find.text('No deadlines due today.'), findsOneWidget);
  });
}
