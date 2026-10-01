import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/learn/presentation/screens/lesson_player_screen.dart';
import 'package:student_mobile/features/notes_bookmarks/data/notes_bookmarks_repository.dart';
import 'package:student_mobile/features/notes_bookmarks/domain/notes_bookmarks_models.dart';

class _FakeLearn implements LearnGateway {
  bool completeCalled = false;

  @override
  Future<MyLearningSnapshot> loadMyLearning() async {
    return const MyLearningSnapshot();
  }

  @override
  Future<CourseDetailSnapshot> loadCourseDetail(CourseDetailArgs args) async {
    return CourseDetailSnapshot(courseId: args.courseId);
  }

  @override
  Future<LessonDetailSnapshot> loadLesson(LessonDetailArgs args) async {
    return LessonDetailSnapshot(
      lessonId: args.lessonId,
      title: args.title ?? 'Preamble',
      summary: 'Introduction to the Constitution preamble.',
      bodyHtml: '<p>We, the people of India.</p>',
      estimatedMinutes: 15,
      hierarchyLabel: 'Polity Basics · Polity',
      courseId: args.courseId,
      progress: const LessonProgressState(
        status: 'in_progress',
        progressPercent: 40,
      ),
      resources: const [
        LessonResource(
          id: 'r1',
          title: 'Lecture notes',
          resourceType: 'notes',
          contentText: 'Remember the key ideals.',
        ),
        LessonResource(
          id: 'r2',
          title: 'Overview video',
          resourceType: 'video',
          durationSeconds: 600,
        ),
      ],
    );
  }

  @override
  Future<LessonProgressState> completeLesson(String lessonId) async {
    completeCalled = true;
    return const LessonProgressState(
      status: 'completed',
      progressPercent: 100,
      completedAt: '2026-09-15T12:00:00Z',
    );
  }
}

class _FakeBookmarks implements NotesBookmarksGateway {
  NotesBookmarksSnapshot snapshot;
  int addCalls = 0;
  int removeCalls = 0;

  _FakeBookmarks([this.snapshot = const NotesBookmarksSnapshot()]);

  @override
  Future<NotesBookmarksSnapshot> loadLibrary() async => snapshot;

  @override
  Future<StudyNote> createNote({required String body, String? title}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNote(String noteId) async {}

  @override
  Future<ContentBookmark> addBookmark({
    required String bookmarkableType,
    required String bookmarkableId,
    String? title,
  }) async {
    addCalls += 1;
    final bookmark = ContentBookmark(
      id: 'bm-1',
      bookmarkableType: bookmarkableType,
      bookmarkableId: bookmarkableId,
      title: title,
    );
    snapshot = snapshot.copyWith(bookmarks: [bookmark, ...snapshot.bookmarks]);
    return bookmark;
  }

  @override
  Future<void> removeBookmark(String bookmarkId) async {
    removeCalls += 1;
    snapshot = snapshot.copyWith(
      bookmarks: snapshot.bookmarks.where((b) => b.id != bookmarkId).toList(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-22 shows lesson content and resources', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LessonPlayerScreen(
          args: const LessonDetailArgs(
            lessonId: 'l2',
            title: 'Preamble',
            courseId: 'c1',
          ),
          learnRepository: _FakeLearn(),
          bookmarksRepository: _FakeBookmarks(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preamble'), findsWidgets);
    expect(find.text('Polity Basics · Polity'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.textContaining('We, the people of India.'), findsOneWidget);
    expect(find.text('Resources'), findsWidgets);

    final resourcesTab = find.byKey(const ValueKey('lesson-tab-resources'));
    await tester.ensureVisible(resourcesTab);
    await tester.tap(resourcesTab);
    await tester.pumpAndSettle();

    expect(find.text('Lecture notes'), findsOneWidget);
    expect(find.text('Overview video'), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);
  });

  testWidgets('S-22 marks lesson complete', (tester) async {
    final fake = _FakeLearn();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LessonPlayerScreen(
          args: const LessonDetailArgs(lessonId: 'l2', title: 'Preamble'),
          learnRepository: fake,
          bookmarksRepository: _FakeBookmarks(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();

    expect(fake.completeCalled, isTrue);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Lesson marked complete.'), findsOneWidget);
  });

  testWidgets('S-22 bookmark icon saves lesson', (tester) async {
    final bookmarks = _FakeBookmarks();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LessonPlayerScreen(
          args: const LessonDetailArgs(lessonId: 'l2', title: 'Preamble'),
          learnRepository: _FakeLearn(),
          bookmarksRepository: bookmarks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save bookmark'));
    await tester.pumpAndSettle();

    expect(bookmarks.addCalls, 1);
    expect(find.text('Saved to bookmarks'), findsOneWidget);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
  });

  test('stripHtml converts basic tags', () {
    expect(
      stripHtml('<p>Hello<br/>world</p>'),
      contains('Hello'),
    );
    expect(stripHtml('<b>Bold</b> &amp; plain'), 'Bold & plain');
  });
}
