import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tutorials/data/tutorials_repository.dart';
import 'package:student_mobile/features/tutorials/domain/tutorials_models.dart';

/// S-74 Tutorial article reader.
class TutorialArticleScreen extends StatefulWidget {
  const TutorialArticleScreen({
    super.key,
    required this.path,
    this.tutorialsRepository,
  });

  final TutorialPath path;
  final TutorialsGateway? tutorialsRepository;

  @override
  State<TutorialArticleScreen> createState() => _TutorialArticleScreenState();
}

class _TutorialArticleScreenState extends State<TutorialArticleScreen> {
  late final TutorialsGateway _repo =
      widget.tutorialsRepository ?? TutorialsRepository();

  bool _loading = true;
  String? _error;
  TutorialArticleSnapshot? _snapshot;

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
      final snapshot = await _repo.loadArticle(widget.path);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      try {
        await _repo.markProgress(
          articleId: snapshot.article.id,
          completionPercentage: 100,
        );
      } catch (_) {}
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to open this article.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.article.title ?? 'Article';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && _snapshot == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _load,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _snapshot!.article.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                height: 1.2,
                              ),
                            ),
                            if (_snapshot!.article.shortDescription
                                    ?.trim()
                                    .isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              Text(
                                _snapshot!.article.shortDescription!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_snapshot!.article.readingTimeMinutes !=
                                    null)
                                  _Chip(
                                    label:
                                        '${_snapshot!.article.readingTimeMinutes} min read',
                                  ),
                                if (_snapshot!.article.difficulty
                                        ?.isNotEmpty ==
                                    true)
                                  _Chip(
                                    label: _snapshot!.article.difficulty!,
                                  ),
                                if (_snapshot!.article.language?.isNotEmpty ==
                                    true)
                                  _Chip(
                                    label: _snapshot!.article.language!,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SelectableText(
                              _snapshot!.article.plainBody.isEmpty
                                  ? 'No article content available.'
                                  : _snapshot!.article.plainBody,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.55,
                                color: AppColors.ink,
                              ),
                            ),
                            if (_snapshot!
                                .article.revisionBlocks.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              const Text(
                                'Revision',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (final block
                                  in _snapshot!.article.revisionBlocks) ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        block.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        stripHtml(block.html),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                            if (_snapshot!.related.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Related',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final item in _snapshot!.related.take(5))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
