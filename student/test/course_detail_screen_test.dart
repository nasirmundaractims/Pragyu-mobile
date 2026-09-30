import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/learn/presentation/screens/course_detail_screen.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';

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

class _FakeLectures implements LecturesGateway {
  @override
  Future<LecturesSnapshot> loadLectures({String? courseId}) async {
    return LecturesSnapshot(
      upcoming: [
        LectureItem(
          id: 'lec1',
          title: 'Polity Live Class',
          courseId: courseId,
          lectureType: 'live',
          startsAt: DateTime.now().add(const Duration(days: 1)),
        ),
      ],
      recorded: const [
        LectureItem(
          id: 'lec2',
          title: 'Constitution Recorded',
          lectureType: 'recorded',
          hasVideo: true,
          durationSeconds: 1800,
        ),
      ],
    );
  }

  @override
  Future<LiveLobbySnapshot> loadLiveLobby(String lectureId) async {
    return LiveLobbySnapshot(lectureId: lectureId, title: 'Lobby');
  }

  @override
  Future<LiveJoinResult> joinLive(String lectureId) async {
    return const LiveJoinResult(inWaitingRoom: true);
  }

  @override
  Future<List<LiveChatMessage>> listLiveChat(String lectureId) async =>
      const [];

  @override
  Future<LiveChatMessage> postLiveChat(String lectureId, String body) async {
    return LiveChatMessage(
      id: 'm1',
      body: body,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> sendAttendanceHeartbeat(String lectureId) async {}

  @override
  Future<RecordedLectureSnapshot> loadRecordedLecture(String lectureId) async {
    return RecordedLectureSnapshot(lectureId: lectureId, title: 'Recorded');
  }

  @override
  Future<LecturePlaybackInfo> loadPlayback(String lectureId) async {
    return const LecturePlaybackInfo();
  }

  @override
  Future<RecordedLectureSnapshot> completeRecordedLecture(
    String lectureId,
  ) async {
    return RecordedLectureSnapshot(lectureId: lectureId, title: 'Recorded');
  }

  @override
  Future<void> reportPlaybackProgress({
    required String lectureId,
    required int positionSeconds,
    int? deltaSeconds,
    int? progressPercent,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-21 shows progress, modules, and inline lectures', (
    tester,
  ) async {
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
          lecturesRepository: _FakeLectures(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UPSC GS Foundation'), findsWidgets);
    expect(find.text('UPSC CSE'), findsOneWidget);
    expect(find.text('40% complete'), findsOneWidget);
    expect(find.text('2/5 lessons'), findsOneWidget);
    expect(find.textContaining('Continue: Preamble'), findsOneWidget);
    expect(find.textContaining('Lectures'), findsWidgets);
    expect(find.text('Materials'), findsOneWidget);
    expect(find.text('Modules'), findsOneWidget);
    expect(find.text('Polity Basics'), findsOneWidget);
    expect(find.text('Constitution'), findsOneWidget);
    expect(find.text('Preamble'), findsWidgets);
    expect(find.text('Live, upcoming & recorded classes'), findsOneWidget);
    expect(find.text('Polity Live Class'), findsOneWidget);
    expect(find.text('Constitution Recorded'), findsOneWidget);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Recorded'), findsWidgets);
  });

  testWidgets('S-21 empty modules state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CourseDetailScreen(
          args: const CourseDetailArgs(courseId: 'empty'),
          learnRepository: _EmptyLearn(),
          lecturesRepository: _EmptyLectures(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No modules published in this course yet.'), findsOneWidget);
    expect(find.textContaining('Continue:'), findsNothing);
    expect(
      find.text('No lectures published for this course yet.'),
      findsOneWidget,
    );
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

class _EmptyLectures implements LecturesGateway {
  @override
  Future<LecturesSnapshot> loadLectures({String? courseId}) async {
    return const LecturesSnapshot();
  }

  @override
  Future<LiveLobbySnapshot> loadLiveLobby(String lectureId) async {
    return LiveLobbySnapshot(lectureId: lectureId, title: 'Lobby');
  }

  @override
  Future<LiveJoinResult> joinLive(String lectureId) async {
    return const LiveJoinResult(inWaitingRoom: true);
  }

  @override
  Future<List<LiveChatMessage>> listLiveChat(String lectureId) async =>
      const [];

  @override
  Future<LiveChatMessage> postLiveChat(String lectureId, String body) async {
    return LiveChatMessage(
      id: 'm1',
      body: body,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> sendAttendanceHeartbeat(String lectureId) async {}

  @override
  Future<RecordedLectureSnapshot> loadRecordedLecture(String lectureId) async {
    return RecordedLectureSnapshot(lectureId: lectureId, title: 'Recorded');
  }

  @override
  Future<LecturePlaybackInfo> loadPlayback(String lectureId) async {
    return const LecturePlaybackInfo();
  }

  @override
  Future<RecordedLectureSnapshot> completeRecordedLecture(
    String lectureId,
  ) async {
    return RecordedLectureSnapshot(lectureId: lectureId, title: 'Recorded');
  }

  @override
  Future<void> reportPlaybackProgress({
    required String lectureId,
    required int positionSeconds,
    int? deltaSeconds,
    int? progressPercent,
  }) async {}
}
