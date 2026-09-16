import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/notes_bookmarks/data/notes_bookmarks_repository.dart';
import 'package:student_mobile/features/notes_bookmarks/domain/notes_bookmarks_models.dart';
import 'package:student_mobile/features/notes_bookmarks/presentation/screens/notes_bookmarks_screen.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

class _FakeLibrary implements NotesBookmarksGateway {
  _FakeLibrary(this.snapshot);

  NotesBookmarksSnapshot snapshot;
  int createCalls = 0;
  int deleteNoteCalls = 0;
  int removeBookmarkCalls = 0;

  @override
  Future<NotesBookmarksSnapshot> loadLibrary() async => snapshot;

  @override
  Future<StudyNote> createNote({
    required String body,
    String? title,
  }) async {
    createCalls += 1;
    final note = StudyNote(
      id: 'n-new',
      body: body,
      title: title,
      updatedAt: DateTime(2026, 9, 16),
    );
    snapshot = snapshot.copyWith(notes: [note, ...snapshot.notes]);
    return note;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    deleteNoteCalls += 1;
    snapshot = snapshot.copyWith(
      notes: snapshot.notes.where((n) => n.id != noteId).toList(),
    );
  }

  @override
  Future<void> removeBookmark(String bookmarkId) async {
    removeBookmarkCalls += 1;
    snapshot = snapshot.copyWith(
      bookmarks: snapshot.bookmarks.where((b) => b.id != bookmarkId).toList(),
    );
  }
}

void main() {
  testWidgets('S-64 shows notes and creates a note', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLibrary(
      const NotesBookmarksSnapshot(
        notes: [
          StudyNote(
            id: 'n1',
            title: 'Federalism',
            body: 'Compare Union and State lists.',
          ),
        ],
        bookmarks: [
          ContentBookmark(
            id: 'b1',
            bookmarkableType: 'lesson',
            bookmarkableId: 'l1',
            title: 'DPSP lesson',
          ),
        ],
        feedback: [
          FeedbackReportItem(
            submissionId: 's1',
            assessmentId: 'a1',
            title: 'Polity Quiz',
            percentage: 78,
            totalScore: 15.6,
            maxScore: 20,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: NotesBookmarksScreen(libraryRepository: fake),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.resultFeedback) {
            final args = ResultFeedbackArgs.fromObject(settings.arguments);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text('Feedback ${args.submissionId}'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notes, bookmarks & feedback'), findsOneWidget);
    expect(find.text('Federalism'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('DPSP lesson'), findsOneWidget);

    await tester.tap(find.text('AI reports'));
    await tester.pumpAndSettle();
    expect(find.text('Polity Quiz'), findsOneWidget);

    await tester.ensureVisible(find.text('Polity Quiz'));
    await tester.tap(find.text('Polity Quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Feedback s1'), findsOneWidget);
  });

  testWidgets('S-64 empty notes can add a note', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLibrary(const NotesBookmarksSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: NotesBookmarksScreen(libraryRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsOneWidget);

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();

    final noteFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(noteFields, findsNWidgets(2));
    await tester.enterText(noteFields.at(1), 'Revision tip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.createCalls, 1);
    expect(find.text('Revision tip'), findsWidgets);
    expect(find.text('No notes yet'), findsNothing);
  });
}
