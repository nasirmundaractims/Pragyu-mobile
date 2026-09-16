/// S-74 Tutorials / exam guides models.

class TutorialPath {
  const TutorialPath({
    this.contextSlug,
    this.subjectSlug,
    this.topicSlug,
    this.articleSlug,
  });

  final String? contextSlug;
  final String? subjectSlug;
  final String? topicSlug;
  final String? articleSlug;

  bool get hasContext => contextSlug?.isNotEmpty == true;
  bool get hasSubject => subjectSlug?.isNotEmpty == true;
  bool get hasTopic => topicSlug?.isNotEmpty == true;
  bool get hasArticle => articleSlug?.isNotEmpty == true;

  factory TutorialPath.fromHref(String? href) {
    if (href == null || href.isEmpty) return const TutorialPath();
    final uri = Uri.tryParse(href);
    final segments = (uri?.pathSegments.isNotEmpty == true)
        ? uri!.pathSegments
        : href.split('/').where((s) => s.isNotEmpty).toList();
    final start = segments.indexWhere((s) => s == 'tutorials');
    final parts = start >= 0 ? segments.sublist(start + 1) : segments;
    return TutorialPath(
      contextSlug: parts.isNotEmpty ? parts[0] : null,
      subjectSlug: parts.length > 1 ? parts[1] : null,
      topicSlug: parts.length > 2 ? parts[2] : null,
      articleSlug: parts.length > 3 ? parts[3] : null,
    );
  }

  factory TutorialPath.fromObject(Object? raw) {
    if (raw is TutorialPath) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return TutorialPath(
        contextSlug: map['contextSlug']?.toString() ??
            map['context']?.toString() ??
            map['context_slug']?.toString(),
        subjectSlug: map['subjectSlug']?.toString() ??
            map['subject']?.toString() ??
            map['subject_slug']?.toString(),
        topicSlug: map['topicSlug']?.toString() ??
            map['topic']?.toString() ??
            map['topic_slug']?.toString(),
        articleSlug: map['articleSlug']?.toString() ??
            map['article']?.toString() ??
            map['article_slug']?.toString(),
      );
    }
    if (raw is String) return TutorialPath.fromHref(raw);
    return const TutorialPath();
  }
}

class TutorialContextCard {
  const TutorialContextCard({
    required this.id,
    required this.name,
    required this.slug,
    this.type = 'exam',
    this.description,
    this.href,
  });

  final String id;
  final String name;
  final String slug;
  final String type;
  final String? description;
  final String? href;

  factory TutorialContextCard.fromJson(Map<String, dynamic> json) {
    return TutorialContextCard(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? 'Guide').toString(),
      slug: json['slug']?.toString() ?? '',
      type: (json['type'] ?? 'exam').toString(),
      description: json['description']?.toString(),
      href: json['href']?.toString(),
    );
  }
}

class TutorialSubjectCard {
  const TutorialSubjectCard({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.href,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? href;

  factory TutorialSubjectCard.fromJson(Map<String, dynamic> json) {
    return TutorialSubjectCard(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? 'Subject').toString(),
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      href: json['href']?.toString(),
    );
  }
}

class TutorialTopicNode {
  const TutorialTopicNode({
    required this.id,
    required this.name,
    required this.slug,
    this.shortDescription,
    this.href,
    this.children = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final String? href;
  final List<TutorialTopicNode> children;

  factory TutorialTopicNode.fromJson(Map<String, dynamic> json) {
    final childrenRaw = json['children'];
    final children = <TutorialTopicNode>[];
    if (childrenRaw is List) {
      for (final row in childrenRaw) {
        if (row is! Map) continue;
        children.add(
          TutorialTopicNode.fromJson(
            row.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      }
    }
    return TutorialTopicNode(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? 'Topic').toString(),
      slug: json['slug']?.toString() ?? '',
      shortDescription: json['short_description']?.toString(),
      href: json['href']?.toString(),
      children: children,
    );
  }
}

class TutorialArticleCard {
  const TutorialArticleCard({
    required this.id,
    required this.title,
    required this.slug,
    this.shortDescription,
    this.difficulty,
    this.language,
    this.readingTimeMinutes,
    this.contextName,
    this.subjectName,
    this.topicName,
    this.href,
    this.completionPercentage,
  });

  final String id;
  final String title;
  final String slug;
  final String? shortDescription;
  final String? difficulty;
  final String? language;
  final int? readingTimeMinutes;
  final String? contextName;
  final String? subjectName;
  final String? topicName;
  final String? href;
  final double? completionPercentage;

  String get metaLabel {
    final parts = <String>[
      if (contextName?.isNotEmpty == true) contextName!,
      if (subjectName?.isNotEmpty == true) subjectName!,
      if (readingTimeMinutes != null) '$readingTimeMinutes min',
      if (difficulty?.isNotEmpty == true) difficulty!,
    ];
    return parts.join(' · ');
  }

  TutorialPath get path => TutorialPath.fromHref(href);

  factory TutorialArticleCard.fromJson(Map<String, dynamic> json) {
    final nested = json['article'];
    final source = nested is Map
        ? nested.map((k, v) => MapEntry(k.toString(), v))
        : json;
    return TutorialArticleCard(
      id: (source['id'] ?? json['article_id'] ?? json['id'])?.toString() ?? '',
      title: (source['title'] ?? 'Article').toString(),
      slug: source['slug']?.toString() ?? '',
      shortDescription: source['short_description']?.toString(),
      difficulty: source['difficulty']?.toString(),
      language: source['language']?.toString(),
      readingTimeMinutes: _int(source['reading_time_minutes']),
      contextName: source['context_name']?.toString(),
      subjectName: source['subject_name']?.toString(),
      topicName: source['topic_name']?.toString(),
      href: source['href']?.toString(),
      completionPercentage: _num(json['completion_percentage']),
    );
  }
}

class TutorialArticleDetail {
  const TutorialArticleDetail({
    required this.id,
    required this.title,
    required this.slug,
    this.shortDescription,
    this.contentHtml,
    this.difficulty,
    this.language,
    this.readingTimeMinutes,
    this.revisionBlocks = const [],
  });

  final String id;
  final String title;
  final String slug;
  final String? shortDescription;
  final String? contentHtml;
  final String? difficulty;
  final String? language;
  final int? readingTimeMinutes;
  final List<({String title, String html})> revisionBlocks;

  String get plainBody => stripHtml(contentHtml ?? '');

  factory TutorialArticleDetail.fromJson(Map<String, dynamic> json) {
    final blocksRaw = json['revision_blocks'];
    final blocks = <({String title, String html})>[];
    if (blocksRaw is List) {
      for (final row in blocksRaw) {
        if (row is! Map) continue;
        final map = row.map((k, v) => MapEntry(k.toString(), v));
        blocks.add((
          title: (map['title'] ?? 'Revision').toString(),
          html: (map['html'] ?? '').toString(),
        ));
      }
    }
    return TutorialArticleDetail(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? 'Article').toString(),
      slug: json['slug']?.toString() ?? '',
      shortDescription: json['short_description']?.toString(),
      contentHtml: json['content_html']?.toString(),
      difficulty: json['difficulty']?.toString(),
      language: json['language']?.toString(),
      readingTimeMinutes: _int(json['reading_time_minutes']),
      revisionBlocks: blocks,
    );
  }
}

class TutorialsHomeSnapshot {
  const TutorialsHomeSnapshot({
    this.contexts = const [],
    this.featuredArticles = const [],
    this.recentArticles = const [],
    this.continueReading = const [],
    this.recentlyViewed = const [],
    this.recommendations = const [],
  });

  final List<TutorialContextCard> contexts;
  final List<TutorialArticleCard> featuredArticles;
  final List<TutorialArticleCard> recentArticles;
  final List<TutorialArticleCard> continueReading;
  final List<TutorialArticleCard> recentlyViewed;
  final List<TutorialArticleCard> recommendations;

  List<TutorialArticleCard> get recentlyAdded =>
      recentArticles.isNotEmpty ? recentArticles : featuredArticles;
}

class TutorialContextSnapshot {
  const TutorialContextSnapshot({
    required this.context,
    this.subjects = const [],
  });

  final TutorialContextCard context;
  final List<TutorialSubjectCard> subjects;
}

class TutorialSubjectSnapshot {
  const TutorialSubjectSnapshot({
    required this.contextSlug,
    required this.subject,
    this.topics = const [],
    this.articles = const [],
  });

  final String contextSlug;
  final TutorialSubjectCard subject;
  final List<TutorialTopicNode> topics;
  final List<TutorialArticleCard> articles;
}

class TutorialTopicSnapshot {
  const TutorialTopicSnapshot({
    required this.contextSlug,
    required this.subjectSlug,
    required this.topic,
    this.childTopics = const [],
    this.articles = const [],
  });

  final String contextSlug;
  final String subjectSlug;
  final TutorialTopicNode topic;
  final List<TutorialTopicNode> childTopics;
  final List<TutorialArticleCard> articles;
}

class TutorialArticleSnapshot {
  const TutorialArticleSnapshot({
    required this.path,
    required this.article,
    this.related = const [],
  });

  final TutorialPath path;
  final TutorialArticleDetail article;
  final List<TutorialArticleCard> related;
}

String stripHtml(String html) {
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return text;
}

int? _int(Object? raw) {
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

double? _num(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}
