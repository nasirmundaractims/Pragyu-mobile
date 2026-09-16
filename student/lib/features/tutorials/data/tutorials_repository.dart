import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/tutorials/domain/tutorials_models.dart';

abstract class TutorialsGateway {
  Future<TutorialsHomeSnapshot> loadHome();
  Future<TutorialContextSnapshot> loadContext(String contextSlug);
  Future<TutorialSubjectSnapshot> loadSubject({
    required String contextSlug,
    required String subjectSlug,
  });
  Future<TutorialTopicSnapshot> loadTopic({
    required String contextSlug,
    required String subjectSlug,
    required String topicSlug,
  });
  Future<TutorialArticleSnapshot> loadArticle(TutorialPath path);
  Future<void> markProgress({
    required String articleId,
    double completionPercentage = 100,
  });
}

class TutorialsRepository implements TutorialsGateway {
  TutorialsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<TutorialsHomeSnapshot> loadHome() async {
    final envelope = await _api.get('/public/tutorials');
    final data = _asMap(envelope['data']);

    final contexts = _mapList(data['contexts'], TutorialContextCard.fromJson);
    final featured =
        _mapList(data['featured_articles'], TutorialArticleCard.fromJson);
    final recent =
        _mapList(data['recent_articles'], TutorialArticleCard.fromJson);

    var continueReading = const <TutorialArticleCard>[];
    var recentlyViewed = const <TutorialArticleCard>[];
    var recommendations = const <TutorialArticleCard>[];

    final session = await _session.read();
    if (session != null) {
      continueReading = await _listMeArticles(
        session,
        '/me/tutorials/continue',
        limit: 6,
      );
      recentlyViewed = await _listMeArticles(
        session,
        '/me/tutorials/recent',
        limit: 6,
      );
      recommendations = await _listMeArticles(
        session,
        '/me/tutorials/recommendations',
        limit: 6,
      );
    }

    return TutorialsHomeSnapshot(
      contexts: contexts,
      featuredArticles: featured,
      recentArticles: recent,
      continueReading: continueReading,
      recentlyViewed: recentlyViewed,
      recommendations: recommendations,
    );
  }

  @override
  Future<TutorialContextSnapshot> loadContext(String contextSlug) async {
    final envelope = await _api.get('/public/tutorials/$contextSlug');
    final data = _asMap(envelope['data']);
    final contextJson = _asMap(data['context']);
    final context = contextJson.isEmpty
        ? TutorialContextCard(
            id: contextSlug,
            name: contextSlug,
            slug: contextSlug,
          )
        : TutorialContextCard.fromJson(contextJson);
    return TutorialContextSnapshot(
      context: context.slug.isEmpty
          ? TutorialContextCard(
              id: context.id,
              name: context.name,
              slug: contextSlug,
              type: context.type,
              description: context.description,
              href: context.href,
            )
          : context,
      subjects: _mapList(data['subjects'], TutorialSubjectCard.fromJson),
    );
  }

  @override
  Future<TutorialSubjectSnapshot> loadSubject({
    required String contextSlug,
    required String subjectSlug,
  }) async {
    final envelope =
        await _api.get('/public/tutorials/$contextSlug/$subjectSlug');
    final data = _asMap(envelope['data']);
    final subjectJson = _asMap(data['subject']);
    final subject = subjectJson.isEmpty
        ? TutorialSubjectCard(
            id: subjectSlug,
            name: subjectSlug,
            slug: subjectSlug,
          )
        : TutorialSubjectCard.fromJson(subjectJson);
    return TutorialSubjectSnapshot(
      contextSlug: contextSlug,
      subject: subject.slug.isEmpty
          ? TutorialSubjectCard(
              id: subject.id,
              name: subject.name,
              slug: subjectSlug,
              description: subject.description,
              href: subject.href,
            )
          : subject,
      topics: _mapList(data['topics'], TutorialTopicNode.fromJson),
      articles: _mapList(data['articles'], TutorialArticleCard.fromJson),
    );
  }

  @override
  Future<TutorialTopicSnapshot> loadTopic({
    required String contextSlug,
    required String subjectSlug,
    required String topicSlug,
  }) async {
    final envelope = await _api.get(
      '/public/tutorials/$contextSlug/$subjectSlug/$topicSlug',
    );
    final data = _asMap(envelope['data']);
    final topicJson = _asMap(data['topic']);
    final topic = topicJson.isEmpty
        ? TutorialTopicNode(
            id: topicSlug,
            name: topicSlug,
            slug: topicSlug,
          )
        : TutorialTopicNode.fromJson(topicJson);
    return TutorialTopicSnapshot(
      contextSlug: contextSlug,
      subjectSlug: subjectSlug,
      topic: topic.slug.isEmpty
          ? TutorialTopicNode(
              id: topic.id,
              name: topic.name,
              slug: topicSlug,
              shortDescription: topic.shortDescription,
              href: topic.href,
              children: topic.children,
            )
          : topic,
      childTopics: _mapList(data['child_topics'], TutorialTopicNode.fromJson),
      articles: _mapList(data['articles'], TutorialArticleCard.fromJson),
    );
  }

  @override
  Future<TutorialArticleSnapshot> loadArticle(TutorialPath path) async {
    if (!path.hasContext ||
        !path.hasSubject ||
        !path.hasTopic ||
        !path.hasArticle) {
      throw ArgumentError('Full tutorial article path is required.');
    }
    final envelope = await _api.get(
      '/public/tutorials/${path.contextSlug}/${path.subjectSlug}/${path.topicSlug}/${path.articleSlug}',
    );
    final data = _asMap(envelope['data']);
    final articleJson = _asMap(data['article']);
    final article = TutorialArticleDetail.fromJson(
      articleJson.isEmpty ? data : articleJson,
    );
    final related =
        _mapList(data['related_articles'], TutorialArticleCard.fromJson);

    final session = await _session.read();
    if (session != null && article.id.isNotEmpty) {
      try {
        await _api.post(
          '/me/tutorials/${article.id}/progress',
          body: {
            'completion_percentage': 5,
            'scroll_percentage': 5,
            'surface': 'mobile_article_reader',
          },
          accessToken: session.accessToken,
          organizationId: session.organizationId,
        );
      } catch (_) {}
    }

    return TutorialArticleSnapshot(
      path: path,
      article: article,
      related: related,
    );
  }

  @override
  Future<void> markProgress({
    required String articleId,
    double completionPercentage = 100,
  }) async {
    final session = await _session.read();
    if (session == null || articleId.isEmpty) return;
    await _api.post(
      '/me/tutorials/$articleId/progress',
      body: {
        'completion_percentage': completionPercentage,
        'scroll_percentage': completionPercentage,
        'surface': 'mobile_article_reader',
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<List<TutorialArticleCard>> _listMeArticles(
    SessionContext session,
    String path, {
    required int limit,
  }) async {
    try {
      final envelope = await _api.get(
        path,
        query: {'limit': '$limit'},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _mapList(envelope['data'], TutorialArticleCard.fromJson);
    } catch (_) {
      return const [];
    }
  }

  List<T> _mapList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) map,
  ) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final row in raw) {
      if (row is! Map) continue;
      out.add(map(row.map((k, v) => MapEntry(k.toString(), v))));
    }
    return out;
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
