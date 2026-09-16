import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// S-44 Submit confirm sheet — review unanswered / marked, then confirm.
Future<bool> showSubmitConfirmSheet({
  required BuildContext context,
  required int total,
  required int answered,
  required int unanswered,
  required int marked,
  List<int> unansweredIndexes = const [],
  List<int> markedIndexes = const [],
  ValueChanged<int>? onReviewQuestion,
  bool busy = false,
}) async {
  final result = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return _SubmitConfirmSheetBody(
        total: total,
        answered: answered,
        unanswered: unanswered,
        marked: marked,
        unansweredIndexes: unansweredIndexes,
        markedIndexes: markedIndexes,
        busy: busy,
      );
    },
  );

  if (result is int) {
    onReviewQuestion?.call(result);
    return false;
  }
  return result == true;
}

class _SubmitConfirmSheetBody extends StatelessWidget {
  const _SubmitConfirmSheetBody({
    required this.total,
    required this.answered,
    required this.unanswered,
    required this.marked,
    required this.unansweredIndexes,
    required this.markedIndexes,
    required this.busy,
  });

  final int total;
  final int answered;
  final int unanswered;
  final int marked;
  final List<int> unansweredIndexes;
  final List<int> markedIndexes;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Submit test?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Once submitted, you cannot change answers. Review your progress before confirming.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(label: 'Total', value: '$total'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'Answered',
                      value: '$answered',
                      valueColor: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Not answered',
                      value: '$unanswered',
                      valueColor: unanswered > 0 ? AppColors.danger : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'Marked',
                      value: '$marked',
                      valueColor: marked > 0 ? const Color(0xFF6B4EFF) : null,
                    ),
                  ),
                ],
              ),
              if (unansweredIndexes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Unanswered',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final index in unansweredIndexes)
                      _QuestionChip(
                        index: index + 1,
                        color: const Color(0xFFFDECEC),
                        textColor: AppColors.danger,
                        onTap: busy
                            ? null
                            : () => Navigator.of(context).pop(index),
                      ),
                  ],
                ),
              ],
              if (markedIndexes.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Marked for review',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final index in markedIndexes)
                      _QuestionChip(
                        index: index + 1,
                        color: const Color(0xFFEEE8FF),
                        textColor: const Color(0xFF6B4EFF),
                        onTap: busy
                            ? null
                            : () => Navigator.of(context).pop(index),
                      ),
                  ],
                ),
              ],
              if (unanswered > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF0D9A8)),
                  ),
                  child: Text(
                    unanswered == 1
                        ? '1 question is still unanswered.'
                        : '$unanswered questions are still unanswered.',
                    style: const TextStyle(
                      color: Color(0xFF8A5A00),
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.brandSoft),
                      ),
                      child: const Text('Continue test'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(busy ? 'Submitting…' : 'Submit now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({
    required this.index,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final int index;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
