import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/tutorials/data/tutorials_repository.dart';
import 'package:student_mobile/features/tutorials/domain/tutorials_models.dart';
import 'package:student_mobile/features/tutorials/presentation/screens/tutorial_article_screen.dart';
import 'package:student_mobile/features/tutorials/presentation/screens/tutorials_browse_screen.dart';
import 'package:student_mobile/features/tutorials/presentation/screens/tutorials_home_screen.dart';

class _FakeTutorials implements TutorialsGateway {
  _FakeTutorials({
    this.home = const TutorialsHomeSnapshot(),
    this.contextSnapshot,
    this.subjectSnapshot,
    this.topicSnapshot,
    this.articleSnapshot,
  });

  TutorialsHomeSnapshot home;
  TutorialContextSnapshot? contextSnapshot;
  TutorialSubjectSnapshot? subjectSnapshot;
  TutorialTopicSnapshot? topicSnapshot;
  TutorialArticleSnapshot? articleSnapshot;
  final marked = <String>[];

  @override
  Future<TutorialsHomeSnapshot> loadHome() async => home;

  @override
  Future<TutorialContextSnapshot> loadContext(String contextSlug) async {
    return contextSnapshot ??
        TutorialContextSnapshot(
          context: TutorialContextCard(
            id: contextSlug,
            name: contextSlug,
            slug: contextSlug,
          ),
        );
  }

  @override
  Future<TutorialSubjectSnapshot> loadSubject({
    required String contextSlug,
    required String subjectSlug,
  }) async {
    return subjectSnapshot ??
        TutorialSubjectSnapshot(
          contextSlug: contextSlug,
          subject: TutorialSubjectCard(
            id: subjectSlug,
            name: subjectSlug,
            slug: subjectSlug,
          ),
        );
  }

  @override
  Future<TutorialTopicSnapshot> loadTopic({
    required String contextSlug,
    required String subjectSlug,
    required String topicSlug,
  }) async {
    return topicSnapshot ??
        TutorialTopicSnapshot(
          contextSlug: contextSlug,
          subjectSlug: subjectSlug,
          topic: TutorialTopicNode(
            id: topicSlug,
            name: topicSlug,
            slug: topicSlug,
          ),
        );
  }

  @override
  Future<TutorialArticleSnapshot> loadArticle(TutorialPath path) async {
    return articleSnapshot ??
        TutorialArticleSnapshot(
          path: path,
          article: TutorialArticleDetail(
            id: 'a1',
            title: 'Sample',
            slug: path.articleSlug ?? 'sample',
            contentHtml: '<p>Body</p>',
          ),
        );
  }

  @override
  Future<void> markProgress({
    required String articleId,
    double completionPercentage = 100,
  }) async {
    marked.add(articleId);
  }
}

void main() {
  testWidgets('S-74 home shows contexts and personalized strips',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeTutorials(
      home: TutorialsHomeSnapshot(
        contexts: const [
          TutorialContextCard(
            id: 'c1',
            name: 'GPSC',
            slug: 'gpsc',
            type: 'exam',
            description: 'Gujarat exam guides',
          ),
        ],
        continueReading: [
          TutorialArticleCard(
            id: 'a1',
            title: 'Preamble basics',
            slug: 'preamble',
            href: '/tutorials/gpsc/polity/constitution/preamble',
          ),
        ],
        recommendations: const [
          TutorialArticleCard(
            id: 'a2',
            title: 'Rights overview',
            slug: 'rights',
          ),
        ],
        recentArticles: const [
          TutorialArticleCard(
            id: 'a3',
            title: 'New guide',
            slug: 'new-guide',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TutorialsHomeScreen(tutorialsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore tutorials.'), findsOneWidget);
    expect(find.text('Browse by category'), findsOneWidget);
    expect(find.text('GPSC'), findsOneWidget);
    expect(find.text('EXAM'), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Preamble basics'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Recently added'), findsOneWidget);
  });

  testWidgets('S-74 browse lists subjects for a context', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeTutorials(
      contextSnapshot: const TutorialContextSnapshot(
        context: TutorialContextCard(
          id: 'c1',
          name: 'GPSC',
          slug: 'gpsc',
          description: 'Exam guides',
        ),
        subjects: [
          TutorialSubjectCard(
            id: 's1',
            name: 'Polity',
            slug: 'polity',
            description: 'Constitution topics',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TutorialsBrowseScreen(
          path: const TutorialPath(contextSlug: 'gpsc'),
          tutorialsRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subjects'), findsOneWidget);
    expect(find.text('Polity'), findsOneWidget);
    expect(find.text('Constitution topics'), findsOneWidget);
  });

  testWidgets('S-74 article reader shows plain body and marks progress',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeTutorials(
      articleSnapshot: TutorialArticleSnapshot(
        path: const TutorialPath(
          contextSlug: 'gpsc',
          subjectSlug: 'polity',
          topicSlug: 'constitution',
          articleSlug: 'preamble',
        ),
        article: const TutorialArticleDetail(
          id: 'art-1',
          title: 'Preamble',
          slug: 'preamble',
          shortDescription: 'Intro to the Constitution',
          contentHtml: '<p>We the people of India</p>',
          readingTimeMinutes: 5,
          difficulty: 'easy',
          language: 'en',
          revisionBlocks: [
            (title: 'Remember', html: '<p>Key points</p>'),
          ],
        ),
        related: const [
          TutorialArticleCard(
            id: 'a2',
            title: 'Related article',
            slug: 'related',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TutorialArticleScreen(
          path: const TutorialPath(
            contextSlug: 'gpsc',
            subjectSlug: 'polity',
            topicSlug: 'constitution',
            articleSlug: 'preamble',
          ),
          tutorialsRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preamble'), findsWidgets);
    expect(find.text('We the people of India'), findsOneWidget);
    expect(find.text('5 min read'), findsOneWidget);
    expect(find.text('Revision'), findsOneWidget);
    expect(find.text('Remember'), findsOneWidget);
    expect(find.text('Related'), findsOneWidget);
    expect(fake.marked, ['art-1']);
  });
}
