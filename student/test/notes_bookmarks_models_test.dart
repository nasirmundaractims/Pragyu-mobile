import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/notes_bookmarks/domain/notes_bookmarks_models.dart';

void main() {
  test('StudyNote displayTitle falls back to body', () {
    const note = StudyNote(
      id: 'n1',
      body: 'Federalism needs more examples from the Seventh Schedule.',
    );
    expect(note.displayTitle, startsWith('Federalism'));
  });

  test('ContentBookmark maps type labels', () {
    final bookmark = ContentBookmark.fromJson({
      'id': 'b1',
      'bookmarkable_type': 'lesson',
      'bookmarkable_id': 'lesson-9',
      'title': 'Directive Principles',
    });
    expect(bookmark.isLesson, isTrue);
    expect(bookmark.typeLabel, 'Lesson');
    expect(bookmark.displayTitle, 'Directive Principles');
  });

  test('FeedbackReportItem formats score and percent', () {
    final item = FeedbackReportItem.fromSubmissionJson(
      {
        'id': 'sub-1',
        'assessment_id': 'a1',
        'attempt_number': 2,
        'total_score': 16,
        'max_score': 20,
        'percentage': 80,
        'evaluated_at': '2026-09-16T10:00:00Z',
      },
      titles: const {'a1': 'Polity Weekly'},
    );
    expect(item.title, 'Polity Weekly');
    expect(item.scoreLabel, '16 / 20');
    expect(item.percentLabel, '80%');
  });
}
