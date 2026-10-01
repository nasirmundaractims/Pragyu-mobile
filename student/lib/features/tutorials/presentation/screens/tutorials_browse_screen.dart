import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tutorials/data/tutorials_repository.dart';
import 'package:student_mobile/features/tutorials/domain/tutorials_models.dart';

/// S-74 Tutorials browse — context → subject → topic.
class TutorialsBrowseScreen extends StatefulWidget {
  const TutorialsBrowseScreen({
    super.key,
    required this.path,
    this.tutorialsRepository,
  });

  final TutorialPath path;
  final TutorialsGateway? tutorialsRepository;

  @override
  State<TutorialsBrowseScreen> createState() => _TutorialsBrowseScreenState();
}

class _TutorialsBrowseScreenState extends State<TutorialsBrowseScreen> {
  late final TutorialsGateway _repo =
      widget.tutorialsRepository ?? TutorialsRepository();

  bool _loading = true;
  String? _error;
  String _title = 'Tutorials';
  String? _subtitle;
  List<TutorialSubjectCard> _subjects = const [];
  List<TutorialTopicNode> _topics = const [];
  List<TutorialArticleCard> _articles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = widget.path;
      if (path.hasTopic && path.hasSubject && path.hasContext) {
        final snapshot = await _repo.loadTopic(
          contextSlug: path.contextSlug!,
          subjectSlug: path.subjectSlug!,
          topicSlug: path.topicSlug!,
        );
        if (!mounted) return;
        setState(() {
          _title = snapshot.topic.name;
          _subtitle = snapshot.topic.shortDescription;
          _topics = snapshot.childTopics;
          _articles = snapshot.articles;
          _subjects = const [];
          _loading = false;
        });
      } else if (path.hasSubject && path.hasContext) {
        final snapshot = await _repo.loadSubject(
          contextSlug: path.contextSlug!,
          subjectSlug: path.subjectSlug!,
        );
        if (!mounted) return;
        setState(() {
          _title = snapshot.subject.name;
          _subtitle = snapshot.subject.description;
          _topics = snapshot.topics;
          _articles = snapshot.articles;
          _subjects = const [];
          _loading = false;
        });
      } else if (path.hasContext) {
        final snapshot = await _repo.loadContext(path.contextSlug!);
        if (!mounted) return;
        setState(() {
          _title = snapshot.context.name;
          _subtitle = snapshot.context.description;
          _subjects = snapshot.subjects;
          _topics = const [];
          _articles = const [];
          _loading = false;
        });
      } else {
        throw ApiException(message: 'Tutorial path is incomplete.', statusCode: 0);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load this guide.';
      });
    }
  }

  void _openSubject(TutorialSubjectCard subject) {
    Navigator.of(context).pushNamed(
      AppRoutes.tutorialsBrowse,
      arguments: TutorialPath(
        contextSlug: widget.path.contextSlug,
        subjectSlug: subject.slug,
      ),
    );
  }

  void _openTopic(TutorialTopicNode topic) {
    Navigator.of(context).pushNamed(
      AppRoutes.tutorialsBrowse,
      arguments: TutorialPath(
        contextSlug: widget.path.contextSlug,
        subjectSlug: widget.path.subjectSlug,
        topicSlug: topic.slug,
      ),
    );
  }

  void _openArticle(TutorialArticleCard article) {
    final path = article.path.hasArticle
        ? article.path
        : TutorialPath(
            contextSlug: widget.path.contextSlug,
            subjectSlug: widget.path.subjectSlug,
            topicSlug: widget.path.topicSlug ?? article.slug,
            articleSlug: article.slug,
          );
    if (!path.hasArticle) return;
    Navigator.of(context).pushNamed(
      AppRoutes.tutorialsArticle,
      arguments: path,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: _title,
        body: _loading
              ? const AppLoadingState(padding: EdgeInsets.zero)
              : _error != null
                  ? Center(
                      child: AppErrorState(
                        message: _error!,
                        onRetry: _load,
                        retryLabel: 'Retry',
                      ),
                    )
                  : RefreshIndicator(
                      color: StudentHubColors.blue,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: StudentHubColors.ink,
                              ),
                            ),
                            if (_subtitle?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                _subtitle!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: StudentHubColors.muted,
                                ),
                              ),
                            ],
                            if (_subjects.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const StudentSectionHeader(
                                title: 'Subjects',
                                compact: true,
                              ),
                              const SizedBox(height: 8),
                              for (final subject in _subjects) ...[
                                _NavTile(
                                  title: subject.name,
                                  subtitle: subject.description,
                                  onTap: () => _openSubject(subject),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                            if (_topics.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Topics',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: StudentHubColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final topic in _topics) ...[
                                _NavTile(
                                  title: topic.name,
                                  subtitle: topic.shortDescription,
                                  onTap: () => _openTopic(topic),
                                ),
                                const SizedBox(height: 8),
                                for (final child in topic.children) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: _NavTile(
                                      title: child.name,
                                      subtitle: child.shortDescription,
                                      onTap: () => _openTopic(child),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ],
                            if (_articles.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Articles',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: StudentHubColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final article in _articles) ...[
                                _NavTile(
                                  title: article.title,
                                  subtitle: article.metaLabel.isEmpty
                                      ? article.shortDescription
                                      : article.metaLabel,
                                  onTap: () => _openArticle(article),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                            if (_subjects.isEmpty &&
                                _topics.isEmpty &&
                                _articles.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 24),
                                child: Text(
                                  'Nothing published in this section yet.',
                                  style: TextStyle(color: StudentHubColors.muted),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudentHubColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: StudentHubColors.ink,
                      ),
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: StudentHubColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: StudentHubColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
