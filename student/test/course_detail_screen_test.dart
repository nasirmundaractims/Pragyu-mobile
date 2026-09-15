import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/learn/presentation/screens/course_detail_screen.dart';

class _FakeLearn implements LearnGateway {
  @override
  Future<MyLearningSnapshot> loadMyLearning() async {
    return const MyLearningSnapshot();
  }

  @override
  Future<CourseDetailSnapshot> loadCourseDetail(CourseDetailArgs args) async {
    return CourseDetailSnapshot(
      courseId: args.courseId,
      title: args.title ?? 'UPSC GS Foundation',
      programName: args.programName ?? 'UPSC CSE',
      batchName: args.batchName,
      progress: const CourseProgressSummary(
        completionPercent: 40,
        totalLessons: 5,
        completedLessons: 2,
      ),
      continueCursor: const ContinueLearningCursor(
        hasCursor: true,
        courseId: 'c1',
        lessonId: 'l2',
        lessonTitle: 'Preamble',
      ),
      modules: const [
        CourseModule(
          id: 'm1',
          title: 'Polity Basics',
          lessons: [
            CourseLesson(
              id: 'l1',
              title: 'Constitution',
              status: 'completed',
              progressPercent: 100,
              topicPath: 'Polity',
            ),
            CourseLesson(
              id: 'l2',
              title: 'Preamble',
              status: 'in_progress',
              progressPercent: 40,
              topicPath: 'Polity',
              estimatedMinutes: 20,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<LessonDetailSnapshot> loadLesson(LessonDetailArgs args) async {
    return LessonDetailSnapshot(
      lessonId: args.lessonId,
      title: args.title ?? 'Lesson',
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

  testWidgets('S-21 shows progress, continue, and modules', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CourseDetailScreen(
          args: const CourseDetailArgs(
            courseId: 'c1',
            title: 'UPSC GS Foundation',
            programName: 'UPSC CSE',
          ),
          learnRepository: _FakeLearn(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UPSC GS Foundation'), findsWidgets);
    expect(find.text('UPSC CSE'), findsOneWidget);
    expect(find.text('40% complete'), findsOneWidget);
    expect(find.text('2/5 lessons'), findsOneWidget);
    expect(find.textContaining('Continue: Preamble'), findsOneWidget);
    expect(find.text('Lectures'), findsOneWidget);
    expect(find.text('Materials'), findsOneWidget);
    expect(find.text('Modules'), findsOneWidget);
    expect(find.text('Polity Basics'), findsOneWidget);
    expect(find.text('Constitution'), findsOneWidget);
    expect(find.text('Preamble'), findsWidgets);
  });

  testWidgets('S-21 empty modules state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CourseDetailScreen(
          args: const CourseDetailArgs(courseId: 'empty'),
          learnRepository: _EmptyLearn(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No modules published in this course yet.'), findsOneWidget);
    expect(find.textContaining('Continue:'), findsNothing);
  });
}

class _EmptyLearn implements LearnGateway {
  @override
  Future<MyLearningSnapshot> loadMyLearning() async {
    return const MyLearningSnapshot();
  }

  @override
  Future<CourseDetailSnapshot> loadCourseDetail(CourseDetailArgs args) async {
    return CourseDetailSnapshot(
      courseId: args.courseId,
      title: 'Empty Course',
      progress: const CourseProgressSummary(),
    );
  }

  @override
  Future<LessonDetailSnapshot> loadLesson(LessonDetailArgs args) async {
    return LessonDetailSnapshot(
      lessonId: args.lessonId,
      title: 'Lesson',
    );
  }

  @override
  Future<LessonProgressState> completeLesson(String lessonId) async {
    return const LessonProgressState(status: 'completed', progressPercent: 100);
  }
}
