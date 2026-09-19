import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/learn/presentation/screens/course_detail_screen.dart';
import 'package:student_mobile/features/learn/presentation/screens/lesson_player_screen.dart';
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

  @override
  Future<CourseDetailSnapshot> loadCourseDetail(CourseDetailArgs args) async {
    return CourseDetailSnapshot(
      courseId: args.courseId,
      title: args.title ?? 'Course',
      programName: args.programName,
      batchName: args.batchName,
      progress: const CourseProgressSummary(
        completionPercent: 10,
        totalLessons: 1,
        completedLessons: 0,
      ),
      modules: const [
        CourseModule(
          id: 'm1',
          title: 'Module 1',
          lessons: [
            CourseLesson(id: 'l1', title: 'Intro lesson'),
          ],
        ),
      ],
    );
  }

  @override
  Future<LessonDetailSnapshot> loadLesson(LessonDetailArgs args) async {
    return LessonDetailSnapshot(
      lessonId: args.lessonId,
      title: args.title ?? 'Intro lesson',
      summary: 'Welcome to the course.',
      progress: const LessonProgressState(
        status: 'in_progress',
        progressPercent: 0,
      ),
    );
  }

  @override
  Future<LessonProgressState> completeLesson(String lessonId) async {
    return const LessonProgressState(
      status: 'completed',
      progressPercent: 100,
    );
  }
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

    expect(find.text('Learn'), findsOneWidget);
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

    expect(find.text('No enrolled courses yet'), findsOneWidget);
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

    expect(find.text('Learn'), findsWidgets);
    expect(find.text('GPSC Foundation'), findsOneWidget);
  });

  testWidgets('S-20 opens S-21 course detail', (tester) async {
    final fake = _FakeLearn(
      const MyLearningSnapshot(
        courses: [
          LearningCourse(
            courseId: 'c1',
            title: 'UPSC GS Foundation',
            programName: 'UPSC CSE',
            isActive: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.courseDetail) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => CourseDetailScreen(
                args: CourseDetailArgs.fromObject(settings.arguments),
                learnRepository: fake,
              ),
            );
          }
          return onGenerateRoute(settings);
        },
        home: MyLearningScreen(learnRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('UPSC GS Foundation'));
    await tester.pumpAndSettle();

    expect(find.text('10% complete'), findsOneWidget);
    expect(find.text('Modules'), findsOneWidget);
    expect(find.text('Intro lesson'), findsOneWidget);
  });

  testWidgets('S-21 opens S-22 lesson player', (tester) async {
    final fake = _FakeLearn(const MyLearningSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.lessonPlayer) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => LessonPlayerScreen(
                args: LessonDetailArgs.fromObject(settings.arguments),
                learnRepository: fake,
              ),
            );
          }
          return onGenerateRoute(settings);
        },
        home: CourseDetailScreen(
          args: const CourseDetailArgs(
            courseId: 'c1',
            title: 'Course',
          ),
          learnRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final intro = find.text('Intro lesson');
    await tester.scrollUntilVisible(
      intro,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(intro);
    await tester.pumpAndSettle();

    expect(find.text('Welcome to the course.'), findsWidgets);
    expect(find.text('Mark complete'), findsOneWidget);
  });
}
