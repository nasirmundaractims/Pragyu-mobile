import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/recommendations/data/recommendations_repository.dart';
import 'package:student_mobile/features/recommendations/domain/recommendations_models.dart';

/// S-63 Recommendations — AI-prioritized next study actions.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({
    super.key,
    this.recommendationsRepository,
  });

  final RecommendationsGateway? recommendationsRepository;

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  late final RecommendationsGateway _repo =
      widget.recommendationsRepository ?? RecommendationsRepository();

  bool _loading = true;
  bool _generating = false;
  String? _error;
  RecommendationsSnapshot? _snapshot;
  RecommendationGroup? _filter;
  String _query = '';
  final Set<String> _dismissed = {};
  final Set<String> _saved = {};

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
      final snapshot = await _repo.loadRecommendations();
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
            : 'Unable to load recommendations.';
      });
    }
  }

  Future<void> _generate() async {
    final snapshot = _snapshot;
    if (snapshot == null || _generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final items = await _repo.generateRecommendations(
        studentProfileId: snapshot.studentProfileId,
      );
      if (!mounted) return;
      setState(() {
        _generating = false;
        _dismissed.clear();
        _snapshot = snapshot.copyWith(items: items);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recommendations refreshed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to generate recommendations.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _dismiss(RecommendationItem item) async {
    setState(() => _dismissed.add(item.id));
    try {
      await _repo.recordOutcome(
        recommendationId: item.id,
        outcome: 'dismissed',
      );
    } catch (_) {
      // Local hide still applies for this session.
    }
  }

  Future<void> _save(RecommendationItem item) async {
    setState(() => _saved.add(item.id));
    try {
      await _repo.recordOutcome(
        recommendationId: item.id,
        outcome: 'accepted',
      );
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved for later'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _start(RecommendationItem item) {
    final type = item.primaryAction.type.toLowerCase();
    final title = item.title.toLowerCase();
    if (type.contains('coach') ||
        type.contains('mentor') ||
        title.contains('mentor')) {
      Navigator.of(context).pushNamed(AppRoutes.aiMentor);
      return;
    }
    if (type.contains('plan') || title.contains('plan')) {
      Navigator.of(context).pushNamed(AppRoutes.studyPlanner);
      return;
    }
    if (type.contains('revision') ||
        type.contains('weak') ||
        title.contains('revision') ||
        title.contains('weak')) {
      Navigator.of(context).pushNamed(AppRoutes.weakTopics);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.studyPlanner);
  }

  List<RecommendationItem> get _visible {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    return snapshot.filtered(
      group: _filter,
      query: _query,
      dismissed: _dismissed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final visible = _visible;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Recommendations'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: snapshot == null || _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: snapshot == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _generating ? null : _generate,
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_generating ? 'Refreshing…' : 'Refresh'),
              ),
        body: SafeArea(
          child: _loading && snapshot == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && snapshot == null
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            const _HeroBanner(),
                            const SizedBox(height: 14),
                            _MetricsRow(
                              active: visible.length,
                              saved: _saved.length,
                              dismissed: _dismissed.length,
                              weakTopics: snapshot?.weakTopicCount ?? 0,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search recommendations…',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandSoft,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandSoft,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FilterChips(
                              selected: _filter,
                              onSelect: (group) =>
                                  setState(() => _filter = group),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'AI recommendations',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Each card includes reason, time, difficulty, and priority.',
                              style: TextStyle(
                                color: AppColors.muted,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (visible.isEmpty)
                              _EmptyBody(
                                onGenerate: _generating ? null : _generate,
                              )
                            else
                              for (final item in visible) ...[
                                _RecommendationCard(
                                  item: item,
                                  saved: _saved.contains(item.id),
                                  onStart: () => _start(item),
                                  onSave: () => _save(item),
                                  onDismiss: () => _dismiss(item),
                                ),
                                const SizedBox(height: 10),
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

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F0FF), Color(0xFFEEF8F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT BEST ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF6B4E9B),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'AI recommendations for you',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Prioritized from your weak topics, revision signals, and recent assessments.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.active,
    required this.saved,
    required this.dismissed,
    required this.weakTopics,
  });

  final int active;
  final int saved;
  final int dismissed;
  final int weakTopics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Active',
                value: '$active',
                hint: 'AI recommendations',
                color: const Color(0xFF6B4E9B),
                bg: const Color(0xFFF0EBFF),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Saved',
                value: '$saved',
                hint: 'Kept for later',
                color: AppColors.success,
                bg: const Color(0xFFE7F8EF),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Dismissed',
                value: '$dismissed',
                hint: 'Hidden this session',
                color: AppColors.muted,
                bg: const Color(0xFFEEF1F5),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Weak topics',
                value: '$weakTopics',
                hint: 'Driving priorities',
                color: AppColors.danger,
                bg: const Color(0xFFFDEDEC),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    required this.bg,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelect,
  });

  final RecommendationGroup? selected;
  final ValueChanged<RecommendationGroup?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
              selectedColor: AppColors.brandSoft,
              labelStyle: TextStyle(
                color: selected == null ? AppColors.brand : AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final group in RecommendationGroup.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(group.label),
                selected: selected == group,
                onSelected: (_) =>
                    onSelect(selected == group ? null : group),
                selectedColor: AppColors.brandSoft,
                labelStyle: TextStyle(
                  color:
                      selected == group ? AppColors.brand : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.item,
    required this.saved,
    required this.onStart,
    required this.onSave,
    required this.onDismiss,
  });

  final RecommendationItem item;
  final bool saved;
  final VoidCallback onStart;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  Color get _priorityColor {
    switch (item.priority) {
      case RecommendationPriority.critical:
      case RecommendationPriority.high:
        return AppColors.danger;
      case RecommendationPriority.medium:
        return const Color(0xFFE67E22);
      case RecommendationPriority.low:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.priorityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _priorityColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item.whenLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.reason,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.35,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaPill(label: '${item.estimatedMinutes} min'),
              const SizedBox(width: 8),
              _MetaPill(label: item.difficulty),
              if (item.topicPath != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: _MetaPill(label: item.topicPath!, truncate: true),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                ),
                child: Text(item.primaryAction.label),
              ),
              OutlinedButton(
                onPressed: saved ? null : onSave,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brandSoft),
                ),
                child: Text(saved ? 'Saved' : 'Save'),
              ),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    this.truncate = false,
  });

  final String label;
  final bool truncate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.visible,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({this.onGenerate});

  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        children: [
          const Icon(Icons.lightbulb_outline, size: 34, color: AppColors.brand),
          const SizedBox(height: 12),
          const Text(
            'No recommendations right now',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Refresh to generate AI-prioritized next actions from your learning signals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onGenerate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate recommendations'),
          ),
        ],
      ),
    );
  }
}
