import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';

/// S-11 Today detail — full list of today’s classes and deadlines.
class TodayDetailScreen extends StatefulWidget {
  const TodayDetailScreen({
    super.key,
    this.homeRepository,
  });

  final HomeGateway? homeRepository;

  @override
  State<TodayDetailScreen> createState() => _TodayDetailScreenState();
}

class _TodayDetailScreenState extends State<TodayDetailScreen> {
  late final HomeGateway _home = widget.homeRepository ?? HomeRepository();

  bool _loading = true;
  String? _error;
  TodaySnapshot? _snapshot;

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
      final snapshot = await _home.loadToday();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load today’s schedule. Pull to retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Today'),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          _formatDay(snapshot.day),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Classes',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (snapshot.classes.isEmpty)
          const _EmptyBox(text: 'Nothing scheduled for today.')
        else
          ...snapshot.classes.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ClassTile(lecture: item),
            ),
          ),
        const SizedBox(height: 22),
        const Text(
          'Deadlines',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (snapshot.deadlines.isEmpty)
          const _EmptyBox(text: 'No deadlines due today.')
        else
          ...snapshot.deadlines.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DeadlineTile(assessment: item),
            ),
          ),
      ],
    );
  }

  static String _formatDay(DateTime day) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = day.toLocal();
    return '${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]}';
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.lecture});

  final HomeLecture lecture;

  @override
  Widget build(BuildContext context) {
    final live = lecture.isLiveNow;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: live
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.brandSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            live ? 'Live now' : 'Class',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: live ? AppColors.accent : AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lecture.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if ((lecture.subjectName ?? lecture.courseName) != null) ...[
            const SizedBox(height: 4),
            Text(
              [lecture.subjectName, lecture.courseName]
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          if (lecture.startsAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatTime(lecture.startsAt!),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.assessment});

  final HomeAssessment assessment;

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
          Text(
            assessment.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (assessment.due?.label != null) ...[
            const SizedBox(height: 4),
            Text(
              assessment.due!.label!,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.text});

  final String text;

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
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted, height: 1.4),
      ),
    );
  }
}
