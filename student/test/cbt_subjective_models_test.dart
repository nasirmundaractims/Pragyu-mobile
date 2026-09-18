import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';

void main() {
  test('essay questions allow image upload metadata', () {
    final question = AssessmentQuestionPreview.fromJson({
      'id': 'aq1',
      'question_id': 'q1',
      'sort_order': 1,
      'question_snapshot': {
        'type': 'essay',
        'content': '<p>Explain federalism.</p>',
        'metadata': {'word_limit': 250},
      },
    });

    expect(question.type, 'essay');
    expect(question.wordLimit, 250);
    expect(question.allowsImageUpload, isTrue);
    expect(question.kind, CbtQuestionKind.essay);
  });

  test('mcq questions do not allow image upload', () {
    final question = AssessmentQuestionPreview.fromJson({
      'id': 'aq2',
      'question_id': 'q2',
      'sort_order': 2,
      'question_snapshot': {
        'type': 'mcq',
        'metadata': {
          'choices': [
            {'id': 'a', 'label': 'A'},
            {'id': 'b', 'label': 'B'},
          ],
        },
      },
    });

    expect(question.allowsImageUpload, isFalse);
    expect(question.kind, CbtQuestionKind.mcq);
  });

  test('numerical and fill-in map to short text', () {
    final numerical = AssessmentQuestionPreview.fromJson({
      'id': 'aq3',
      'question_id': 'q3',
      'sort_order': 3,
      'question_snapshot': {
        'type': 'numerical',
        'content': 'What is 2 + 2?',
      },
    });
    expect(numerical.kind, CbtQuestionKind.shortText);
    expect(numerical.allowsImageUpload, isTrue);

    final fillIn = AssessmentQuestionPreview.fromJson({
      'id': 'aq4',
      'question_id': 'q4',
      'sort_order': 4,
      'question_snapshot': {
        'type': 'short_answer',
        'content': 'Capital of India is ____',
        'metadata': {'ui_type': 'fill_in_blank'},
      },
    });
    expect(fillIn.uiType, 'fill_in_blank');
    expect(fillIn.kind, CbtQuestionKind.shortText);
  });

  test('keeps passage and content HTML for rich render', () {
    final question = AssessmentQuestionPreview.fromJson({
      'id': 'aq5',
      'question_id': 'q5',
      'sort_order': 5,
      'question_snapshot': {
        'type': 'mcq',
        'content': '<p>Pick the <strong>correct</strong> option.</p>',
        'metadata': {
          'passage': '<p>Read this carefully.</p>',
          'attachments': [
            {
              'url': 'https://cdn.example.com/diagram.png',
              'mime_type': 'image/png',
            },
          ],
          'choices': [
            {'id': 'a', 'label': '<em>One</em>'},
            {'id': 'b', 'label': 'Two'},
          ],
        },
      },
    });

    expect(question.content, contains('Pick the'));
    expect(question.contentHtml, contains('<strong>'));
    expect(question.passageHtml, contains('Read this'));
    expect(question.mediaUrls, ['https://cdn.example.com/diagram.png']);
  });

  test('StudentAnswerValue treats images as answered', () {
    const answer = StudentAnswerValue(
      images: [
        AnswerImageAttachment(
          mediaFileId: 'm1',
          fileName: 'page-1.jpg',
          uploadedAt: '2026-09-16T00:00:00Z',
          pageNumber: 1,
        ),
      ],
    );

    expect(answer.isAnswered, isTrue);
    final roundTrip = StudentAnswerValue.fromJson(answer.toJson());
    expect(roundTrip.images, hasLength(1));
    expect(roundTrip.images.first.mediaFileId, 'm1');
  });

  test('buildMediaFilesMetadata flattens answer images', () {
    final metadata = buildMediaFilesMetadata({
      'q1': const StudentAnswerValue(
        images: [
          AnswerImageAttachment(
            mediaFileId: 'm1',
            fileName: 'page-1.jpg',
            uploadedAt: '2026-09-16T00:00:00Z',
            pageNumber: 1,
          ),
        ],
      ),
    });

    expect(metadata, hasLength(1));
    expect(metadata.first['media_file_id'], 'm1');
    expect(metadata.first['page_number'], 1);
  });
}
