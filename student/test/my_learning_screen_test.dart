import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/learn/presentation/screens/my_learning_screen.dart';

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

class _FakeLearn implements LearnGateway {
  _FakeLearn(this.snapshot);

  final MyLearningSnapshot snapshot;

  @override
  Future<MyLearningSnapshot> loadMyLearning() async => snapshot;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-20 lists enrolled courses with status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MyLearningScreen(
          learnRepository: _FakeLearn(
            const MyLearningSnapshot(
              courses: [
                LearningCourse(
                  courseId: 'c1',
                  title: 'UPSC GS Foundation',
                  programName: 'UPSC CSE',
                  batchName: 'Batch A',
                  isActive: true,
                  status: 'active',
                  progressPercent: 42,
                ),
                LearningCourse(
                  courseId: 'c2',
                  title: 'Polity Elective',
                  isActive: false,
                  status: 'completed',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My learning'), findsOneWidget);
    expect(find.text('UPSC GS Foundation'), findsOneWidget);
    expect(find.text('UPSC CSE · Batch A'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Polity Elective'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('S-20 empty enrolled list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MyLearningScreen(
          learnRepository: _FakeLearn(const MyLearningSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No enrolled courses yet.'), findsOneWidget);
  });

  testWidgets('S-20 Learn tab shows my learning', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(
          initialIndex: 1,
          homeRepository: _FakeHome(),
          learnRepository: _FakeLearn(
            const MyLearningSnapshot(
              courses: [
                LearningCourse(
                  courseId: 'c1',
                  title: 'GPSC Foundation',
                  isActive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My learning'), findsOneWidget);
    expect(find.text('GPSC Foundation'), findsOneWidget);
  });
}
