import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/tutorials/domain/tutorials_models.dart';

void main() {
  test('TutorialPath parses href and object maps', () {
    final fromHref = TutorialPath.fromHref(
      '/tutorials/gpsc/polity/constitution/preamble',
    );
    expect(fromHref.contextSlug, 'gpsc');
    expect(fromHref.subjectSlug, 'polity');
    expect(fromHref.topicSlug, 'constitution');
    expect(fromHref.articleSlug, 'preamble');
    expect(fromHref.hasArticle, isTrue);

    final fromMap = TutorialPath.fromObject({
      'context_slug': 'qiyas',
      'subject': 'math',
      'topicSlug': 'algebra',
      'article': 'equations',
    });
    expect(fromMap.contextSlug, 'qiyas');
    expect(fromMap.subjectSlug, 'math');
    expect(fromMap.topicSlug, 'algebra');
    expect(fromMap.articleSlug, 'equations');
  });

  test('stripHtml converts markup to readable plain text', () {
    final text = stripHtml(
      '<p>Hello&nbsp;<strong>world</strong></p><br/><ul><li>One</li></ul>',
    );
    expect(text.contains('Hello world'), isTrue);
    expect(text.contains('One'), isTrue);
    expect(text.contains('<'), isFalse);
  });

  test('article card meta and detail parse revision blocks', () {
    final card = TutorialArticleCard.fromJson({
      'id': 'a1',
      'title': 'Preamble',
      'slug': 'preamble',
      'context_name': 'GPSC',
      'subject_name': 'Polity',
      'reading_time_minutes': 8,
      'difficulty': 'easy',
      'href': '/tutorials/gpsc/polity/constitution/preamble',
    });
    expect(card.metaLabel, contains('GPSC'));
    expect(card.metaLabel, contains('8 min'));
    expect(card.path.articleSlug, 'preamble');

    final detail = TutorialArticleDetail.fromJson({
      'id': 'a1',
      'title': 'Preamble',
      'slug': 'preamble',
      'content_html': '<p>We the people</p>',
      'revision_blocks': [
        {'title': 'Key idea', 'html': '<p>Remember this</p>'},
      ],
    });
    expect(detail.plainBody, contains('We the people'));
    expect(detail.revisionBlocks, hasLength(1));
    expect(detail.revisionBlocks.first.title, 'Key idea');
  });
}
