import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/student_hub_colors.dart';
import 'package:student_mobile/app/widgets/student_app_header.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tutorials/data/tutorials_repository.dart';
import 'package:student_mobile/features/tutorials/domain/tutorials_models.dart';

/// S-74 Tutorials hub — exam/class guide discovery.
class TutorialsHomeScreen extends StatefulWidget {
  const TutorialsHomeScreen({
    super.key,
    this.tutorialsRepository,
  });

  final TutorialsGateway? tutorialsRepository;

  @override
  State<TutorialsHomeScreen> createState() => _TutorialsHomeScreenState();
}

class _TutorialsHomeScreenState extends State<TutorialsHomeScreen> {
  late final TutorialsGateway _repo =
      widget.tutorialsRepository ?? TutorialsRepository();

  bool _loading = true;
  String? _error;
  TutorialsHomeSnapshot _snapshot = const TutorialsHomeSnapshot();

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
      final snapshot = await _repo.loadHome();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Could not load tutorials right now.';
      });
    }
  }

  void _openContext(TutorialContextCard card) {
    Navigator.of(context).pushNamed(
      AppRoutes.tutorialsBrowse,
      arguments: TutorialPath(contextSlug: card.slug),
    );
  }

  void _openArticle(TutorialArticleCard article) {
    final path = article.path;
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
        title: 'Tutorials',
        body: _loading && _error == null
              ? const Center(
                  child: CircularProgressIndicator(color: StudentHubColors.blue),
                )
              : _error != null && _snapshot.contexts.isEmpty
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: StudentHubColors.blue,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Explore tutorials.',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: StudentHubColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Browse exam, class, and field guides with structured topics and clear articles.',
                              style: TextStyle(
                                fontSize: 13,
                                color: StudentHubColors.muted,
                                height: 1.4,
                              ),
                            ),
                            if (_snapshot.continueReading.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _ArticleStrip(
                                title: 'Continue reading',
                                items: _snapshot.continueReading,
                                onOpen: _openArticle,
                              ),
                            ],
                            if (_snapshot.recommendations.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _ArticleStrip(
                                title: 'Recommended',
                                items: _snapshot.recommendations,
                                onOpen: _openArticle,
                              ),
                            ],
                            if (_snapshot.recentlyViewed.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _ArticleStrip(
                                title: 'Recently viewed',
                                items: _snapshot.recentlyViewed,
                                onOpen: _openArticle,
                              ),
                            ],
                            const SizedBox(height: 18),
                            const Text(
                              'Browse by category',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: StudentHubColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Exams, classes, fields, and custom learning contexts.',
                              style: TextStyle(
                                fontSize: 13,
                                color: StudentHubColors.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_snapshot.contexts.isEmpty)
                              const Text(
                                'No published tutorials yet. Check back soon.',
                                style: TextStyle(color: StudentHubColors.muted),
                              )
                            else
                              for (final item in _snapshot.contexts) ...[
                                _ContextCard(
                                  card: item,
                                  onTap: () => _openContext(item),
                                ),
                                const SizedBox(height: 10),
                              ],
                            if (_snapshot.recentlyAdded.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _ArticleStrip(
                                title: 'Recently added',
                                items: _snapshot.recentlyAdded,
                                onOpen: _openArticle,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.card, required this.onTap});

  final TutorialContextCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudentHubColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StudentHubColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.type.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: StudentHubColors.blue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                card.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: StudentHubColors.ink,
                ),
              ),
              if (card.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  card.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: StudentHubColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleStrip extends StatelessWidget {
  const _ArticleStrip({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final List<TutorialArticleCard> items;
  final ValueChanged<TutorialArticleCard> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: StudentHubColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items.take(6)) ...[
          Material(
            color: StudentHubColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpen(item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: StudentHubColors.ink,
                      ),
                    ),
                    if (item.metaLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.metaLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: StudentHubColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: StudentHubColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: StudentHubColors.blue),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
