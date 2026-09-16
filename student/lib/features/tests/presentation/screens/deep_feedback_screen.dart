import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';

/// S-47 Deep feedback — suggestions, AI rewrite, model answer.
class DeepFeedbackScreen extends StatefulWidget {
  const DeepFeedbackScreen({
    super.key,
    required this.args,
    this.testsRepository,
    this.pollInterval = const Duration(seconds: 4),
  });

  final DeepFeedbackArgs args;
  final TestsGateway? testsRepository;
  final Duration pollInterval;

  @override
  State<DeepFeedbackScreen> createState() => _DeepFeedbackScreenState();
}

class _DeepFeedbackScreenState extends State<DeepFeedbackScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  Timer? _poll;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  DeepFeedbackSnapshot? _snapshot;

  String _style = 'academic';
  String _structure = 'essay';
  int _wordLimit = 200;

  RewriteRequestSummary? _activeRequest;
  RewriteResultPayload? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _tests.loadDeepFeedback(widget.args);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _activeRequest = snapshot.latestRewrite;
        _result = snapshot.rewriteResult;
        _loading = false;
      });
      _schedulePoll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load deep feedback.';
      });
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    final request = _activeRequest;
    if (request == null || !request.isProcessing) return;
    _poll = Timer(widget.pollInterval, _pollRewrite);
  }

  Future<void> _pollRewrite() async {
    final requestId = _activeRequest?.id;
    if (requestId == null || requestId.isEmpty) return;
    try {
      final next = await _tests.getRewriteRequest(requestId);
      RewriteResultPayload? result = _result;
      if (next.isCompleted || !next.isProcessing) {
        result = await _tests.getRewriteResult(requestId) ?? result;
      }
      if (!mounted) return;
      setState(() {
        _activeRequest = next;
        _result = result;
      });
      _schedulePoll();
    } catch (_) {
      if (!mounted) return;
      _schedulePoll();
    }
  }

  Future<void> _requestRewrite() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final language = widget.args.language?.trim().isNotEmpty == true
          ? widget.args.language!.trim()
          : 'en';
      final request = await _tests.requestRewrite(
        widget.args.evaluationId,
        RewriteOptions(
          style: _style,
          examPattern: _structure,
          wordLimit: _wordLimit,
          language: language,
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _activeRequest = request;
        _result = null;
      });
      _schedulePoll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to request AI rewrite.';
      });
    }
  }

  Future<void> _retryProcess() async {
    final requestId = _activeRequest?.id;
    if (requestId == null || requestId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await _tests.processRewrite(requestId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _activeRequest = next;
      });
      _schedulePoll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to retry rewrite.';
      });
    }
  }

  Future<void> _generateSuggestions() async {
    final feedbackId = widget.args.feedbackId?.trim();
    if (feedbackId == null || feedbackId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = await _tests.generateSuggestions(feedbackId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _snapshot = DeepFeedbackSnapshot(
          suggestions: items.isNotEmpty
              ? items
              : (_snapshot?.suggestions ?? const []),
          latestRewrite: _activeRequest ?? _snapshot?.latestRewrite,
          rewriteResult: _result ?? _snapshot?.rewriteResult,
          originalAnswerText: _snapshot?.originalAnswerText,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to generate suggestions.';
      });
    }
  }

  Future<void> _copyText(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.title?.trim().isNotEmpty == true
        ? widget.args.title!.trim()
        : 'AI Answer';

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
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ..._buildBody(),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brand,
                              side: const BorderSide(color: AppColors.brand),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Back to result'),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    final suggestions = _snapshot?.suggestions ?? const [];
    final original = _snapshot?.originalAnswerText;
    final rewritten = _result?.rewrittenText;
    final modelAnswer = _result?.modelAnswer;
    final processing = _activeRequest?.isProcessing == true;
    final failed = _activeRequest?.isFailed == true;

    return [
      const _SectionTitle(title: 'Suggestions'),
      const SizedBox(height: 10),
      if (suggestions.isEmpty)
        _MutedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No personalized suggestions yet.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              if (widget.args.feedbackId?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : _generateSuggestions,
                  child: const Text('Generate suggestions'),
                ),
              ],
            ],
          ),
        )
      else
        ...suggestions.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SuggestionTile(item: item),
          ),
        ),
      const SizedBox(height: 18),
      const _SectionTitle(title: 'Improve answer with AI'),
      const SizedBox(height: 10),
      _RewriteControls(
        style: _style,
        structure: _structure,
        wordLimit: _wordLimit,
        enabled: !_busy && !processing,
        onStyle: (value) => setState(() => _style = value),
        onStructure: (value) => setState(() => _structure = value),
        onWordLimit: (value) => setState(() => _wordLimit = value),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: (_busy || processing) ? null : _requestRewrite,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
        child: Text(
          processing
              ? 'Generating…'
              : (_result != null ? 'Regenerate AI answer' : 'Request AI answer'),
        ),
      ),
      if (_activeRequest != null) ...[
        const SizedBox(height: 10),
        Text(
          'Status: ${_activeRequest!.statusLabel}',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
      if (failed) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _retryProcess,
          child: const Text('Retry processing'),
        ),
      ],
      if (processing) ...[
        const SizedBox(height: 16),
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      ],
      if (original != null && original.isNotEmpty) ...[
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Your answer'),
        const SizedBox(height: 10),
        _TextCard(
          text: original,
          onCopy: () => _copyText('Your answer', original),
        ),
      ],
      if (rewritten != null && rewritten.isNotEmpty) ...[
        const SizedBox(height: 18),
        const _SectionTitle(title: 'AI improved answer'),
        const SizedBox(height: 10),
        _TextCard(
          text: rewritten,
          accent: true,
          footer: _result?.disclaimer,
          onCopy: () => _copyText('AI answer', rewritten),
        ),
      ],
      if (modelAnswer != null && modelAnswer.isNotEmpty) ...[
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Model answer'),
        const SizedBox(height: 10),
        _TextCard(
          text: modelAnswer,
          onCopy: () => _copyText('Model answer', modelAnswer),
        ),
      ],
      if (_result?.improvementItems.isNotEmpty == true) ...[
        const SizedBox(height: 18),
        const _SectionTitle(title: 'What changed'),
        const SizedBox(height: 10),
        _BulletCard(items: _result!.improvementItems),
      ],
      if (_result?.reasoning?.isNotEmpty == true) ...[
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Why this rewrite'),
        const SizedBox(height: 10),
        _MutedCard(
          child: Text(
            _result!.reasoning!,
            style: const TextStyle(color: AppColors.ink, height: 1.45),
          ),
        ),
      ],
    ];
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  const _MutedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: child,
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.item});

  final FeedbackSuggestionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.category != null)
            Text(
              item.category!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 0.4,
              ),
            ),
          if (item.category != null) const SizedBox(height: 6),
          Text(
            item.headline,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (item.description != null &&
              item.description != item.headline) ...[
            const SizedBox(height: 6),
            Text(
              item.description!,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewriteControls extends StatelessWidget {
  const _RewriteControls({
    required this.style,
    required this.structure,
    required this.wordLimit,
    required this.enabled,
    required this.onStyle,
    required this.onStructure,
    required this.onWordLimit,
  });

  final String style;
  final String structure;
  final int wordLimit;
  final bool enabled;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onStructure;
  final ValueChanged<int> onWordLimit;

  @override
  Widget build(BuildContext context) {
    return _MutedCard(
      child: Column(
        children: [
          _DropdownRow<String>(
            label: 'Style',
            value: style,
            enabled: enabled,
            items: const {
              'academic': 'Academic',
              'simple': 'Simple',
              'topper': 'Topper',
              'professional': 'Professional',
            },
            onChanged: onStyle,
          ),
          const SizedBox(height: 12),
          _DropdownRow<String>(
            label: 'Structure',
            value: structure,
            enabled: enabled,
            items: const {
              'essay': 'Essay',
              'short': 'Short answer',
            },
            onChanged: onStructure,
          ),
          const SizedBox(height: 12),
          _DropdownRow<int>(
            label: 'Word target',
            value: wordLimit,
            enabled: enabled,
            items: const {
              100: '100 words',
              200: '200 words',
              300: '300 words',
            },
            onChanged: onWordLimit,
          ),
        ],
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brandSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brandSoft),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                items: [
                  for (final entry in items.entries)
                    DropdownMenuItem<T>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: enabled
                    ? (next) {
                        if (next != null) onChanged(next);
                      }
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.text,
    this.accent = false,
    this.footer,
    this.onCopy,
  });

  final String text;
  final bool accent;
  final String? footer;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? AppColors.brandSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(color: AppColors.ink, height: 1.45),
          ),
          if (footer != null && footer!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              footer!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (onCopy != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _MutedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
