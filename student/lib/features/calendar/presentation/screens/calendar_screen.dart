import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/calendar/data/calendar_repository.dart';
import 'package:student_mobile/features/calendar/domain/calendar_models.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

/// S-30 Calendar — upcoming live classes and test deadlines (agenda list).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.calendarRepository,
  });

  final CalendarGateway? calendarRepository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarGateway _calendar =
      widget.calendarRepository ?? CalendarRepository();

  bool _loading = true;
  String? _error;
  CalendarSnapshot? _snapshot;
  CalendarFilter _filter = CalendarFilter.all;

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
      final snapshot = await _calendar.loadCalendar();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load calendar. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openEvent(CalendarEvent event) {
    if (event.kind == CalendarEventKind.live) {
      Navigator.of(context).pushNamed(
        AppRoutes.liveLobby,
        arguments: LiveLobbyArgs(
          lectureId: event.sourceId,
          title: event.title,
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.assessmentDetail,
      arguments: AssessmentDetailArgs(
        assessmentId: event.sourceId,
        title: event.title,
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
          title: const Text('Calendar'),
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

    final snapshot = _snapshot!.filtered(_filter);
    final horizon = _snapshot!.horizonDays;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          'Upcoming classes and deadlines for the next $horizon days.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: _filter == CalendarFilter.all,
              onTap: () => setState(() => _filter = CalendarFilter.all),
            ),
            _FilterChip(
              label: 'Live',
              selected: _filter == CalendarFilter.live,
              onTap: () => setState(() => _filter = CalendarFilter.live),
            ),
            _FilterChip(
              label: 'Tests',
              selected: _filter == CalendarFilter.tests,
              onTap: () => setState(() => _filter = CalendarFilter.tests),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (snapshot.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text(
              'Nothing upcoming in this window.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          )
        else
          ...snapshot.days.expand((day) {
            return [
              _DayHeader(day: day.day),
              const SizedBox(height: 8),
              ...day.events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EventTile(
                    event: event,
                    onTap: () => _openEvent(event),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ];
          }),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.brandSoft,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDay(day),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }

  static String _formatDay(DateTime day) {
    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
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
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final labelDay = DateTime(local.year, local.month, local.day);
    final prefix = labelDay == startToday
        ? 'Today · '
        : labelDay == startToday.add(const Duration(days: 1))
            ? 'Tomorrow · '
            : '';
    return '$prefix${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]}';
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onTap,
  });

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final live = event.kind == CalendarEventKind.live && event.isLiveNow;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: live
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : AppColors.brandSoft,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                event.kind == CalendarEventKind.live
                    ? Icons.sensors_rounded
                    : Icons.quiz_outlined,
                color: live ? AppColors.accent : AppColors.brand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.kindLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: live ? AppColors.accent : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (event.subtitle != null &&
                        event.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(event.startsAt),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
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

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
