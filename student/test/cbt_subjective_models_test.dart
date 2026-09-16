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
