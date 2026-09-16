import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';

/// S-40 Tests hub — published assessments list for the Tests tab.
class TestsHubScreen extends StatefulWidget {
  const TestsHubScreen({
    super.key,
    this.testsRepository,
  });

  final TestsGateway? testsRepository;

  @override
  State<TestsHubScreen> createState() => _TestsHubScreenState();
}

class _TestsHubScreenState extends State<TestsHubScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  String? _error;
  TestsSnapshot? _snapshot;
  TestsFilter _filter = TestsFilter.all;

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
      final snapshot = await _tests.loadTests();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load tests. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openTest(TestListItem item) {
    Navigator.of(context).pushNamed(
      AppRoutes.assessmentDetail,
      arguments: AssessmentDetailArgs(
        assessmentId: item.id,
        title: item.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Tests'),
          actions: [
            IconButton(
              tooltip: 'Quick search',
              onPressed: () => showQuickSearchSheet(context),
              icon: const Icon(Icons.search_rounded, color: AppColors.ink),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.brand)),
        ],
      );
    }

    if (_error != null && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, height: 1.45),
          ),
        ],
      );
    }

    final snapshot = _snapshot!;
    final filtered = snapshot.filtered(_filter);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'Assigned exams, quizzes, and practice in this institute.',
          style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        _FilterChips(
          selected: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 18),
        if (snapshot.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Text(
              'No tests assigned yet.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          )
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Text(
              'No tests match this filter.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          )
        else
          ...filtered.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TestTile(
                item: item,
                onTap: () => _openTest(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onChanged,
  });

  final TestsFilter selected;
  final ValueChanged<TestsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in TestsFilter.values)
          ChoiceChip(
            label: Text(_filterLabel(filter)),
            selected: selected == filter,
            onSelected: (_) => onChanged(filter),
            selectedColor: AppColors.brandSoft,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected == filter ? AppColors.brand : AppColors.muted,
            ),
            side: BorderSide(
              color: selected == filter
                  ? AppColors.brand.withValues(alpha: 0.35)
                  : AppColors.brandSoft,
            ),
            backgroundColor: AppColors.surface,
            showCheckmark: false,
          ),
      ],
    );
  }

  static String _filterLabel(TestsFilter filter) {
    switch (filter) {
      case TestsFilter.all:
        return 'All';
      case TestsFilter.dueSoon:
        return 'Due soon';
      case TestsFilter.practice:
        return 'Practice';
    }
  }
}

class _TestTile extends StatelessWidget {
  const _TestTile({
    required this.item,
    required this.onTap,
  });

  final TestListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dueLabel = item.due?.label;
    final urgency = item.due?.urgency ?? DueUrgency.none;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brandSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(item.type),
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    if (dueLabel != null && dueLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _DueChip(label: dueLabel, urgency: urgency),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(TestKind type) {
    switch (type) {
      case TestKind.exam:
        return Icons.assignment_outlined;
      case TestKind.quiz:
        return Icons.quiz_outlined;
      case TestKind.assignment:
        return Icons.edit_note_outlined;
      case TestKind.practice:
        return Icons.fitness_center_outlined;
      case TestKind.other:
        return Icons.fact_check_outlined;
    }
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({
    required this.label,
    required this.urgency,
  });

  final String label;
  final DueUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final urgent = urgency == DueUrgency.overdue ||
        urgency == DueUrgency.endsSoon ||
        urgency == DueUrgency.dueToday;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFDECEC) : const Color(0xFFE6F5EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: urgent ? AppColors.danger : AppColors.success,
        ),
      ),
    );
  }
}
