import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';

/// S-24 Live class lobby — status, countdown, check-in / join.
class LiveLobbyScreen extends StatefulWidget {
  const LiveLobbyScreen({
    super.key,
    required this.args,
    this.lecturesRepository,
    this.pollInterval = const Duration(seconds: 4),
  });

  final LiveLobbyArgs args;
  final LecturesGateway? lecturesRepository;

  /// Set to `null` or [Duration.zero] to disable polling (tests).
  final Duration? pollInterval;

  @override
  State<LiveLobbyScreen> createState() => _LiveLobbyScreenState();
}

class _LiveLobbyScreenState extends State<LiveLobbyScreen> {
  late final LecturesGateway _lectures =
      widget.lecturesRepository ?? LecturesRepository();

  bool _loading = true;
  bool _acting = false;
  String? _error;
  LiveLobbySnapshot? _snapshot;
  Timer? _poll;
  Timer? _countdownTick;

  @override
  void initState() {
    super.initState();
    _load();
    final interval = widget.pollInterval;
    if (interval != null && interval > Duration.zero) {
      _countdownTick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && _snapshot != null) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _countdownTick?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    final interval = widget.pollInterval;
    if (interval == null || interval <= Duration.zero) return;
    _poll = Timer.periodic(interval, (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _lectures.loadLiveLobby(widget.args.lectureId);
      if (!mounted) return;
      setState(() {
        // Preserve check-in flag across silent polls until session changes.
        final previous = _snapshot;
        _snapshot = snapshot.copyWith(
          checkedIn: previous?.checkedIn == true &&
                  snapshot.sessionStatus == LiveSessionStatus.waiting
              ? true
              : snapshot.checkedIn,
          inWaitingRoom: previous?.inWaitingRoom == true &&
                  snapshot.sessionStatus == LiveSessionStatus.waiting
              ? true
              : snapshot.inWaitingRoom,
        );
        _loading = false;
        _error = null;
      });
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      if (silent && _snapshot != null) return;
      setState(() {
        _error = 'Unable to load this live class. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _onPrimaryAction() async {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.canAct || _acting) return;

    setState(() => _acting = true);
    try {
      final result = await _lectures.joinLive(snapshot.lectureId);
      if (!mounted) return;

      if (result.hasMediaToken && !result.inWaitingRoom) {
        setState(() {
          _snapshot = snapshot.copyWith(
            checkedIn: true,
            inWaitingRoom: false,
            sessionStatus: LiveSessionStatus.live,
          );
          _acting = false;
        });
        if (!mounted) return;
        await Navigator.of(context).pushNamed(
          AppRoutes.liveRoom,
          arguments: LiveRoomArgs(
            lectureId: snapshot.lectureId,
            title: snapshot.title,
            mediaUrl: result.mediaUrl,
          ),
        );
        await _load(silent: true);
        return;
      }

      setState(() {
        _snapshot = snapshot.copyWith(
          checkedIn: true,
          inWaitingRoom: result.inWaitingRoom ||
              snapshot.sessionStatus == LiveSessionStatus.waiting,
          sessionStatus:
              result.sessionStatus ?? snapshot.sessionStatus,
        );
        _acting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.inWaitingRoom ||
                    snapshot.sessionStatus == LiveSessionStatus.waiting
                ? 'Checked in — your teacher will let you in soon.'
                : 'Joined the waiting room.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load(silent: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to join. Is the class open?'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Live class');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Live lobby'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: () => _load(),
            child: _buildBody(title),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget? _buildBottomBar() {
    final snapshot = _snapshot;
    if (snapshot == null) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: snapshot.canAct && !_acting ? _onPrimaryAction : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.brandSoft,
            disabledForegroundColor: AppColors.muted,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _acting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                )
              : Text(snapshot.primaryActionLabel),
        ),
      ),
    );
  }

  Widget _buildBody(String title) {
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
    final subtitle = [
      if (snapshot.subjectName != null && snapshot.subjectName!.isNotEmpty)
        snapshot.subjectName,
      if (snapshot.courseName != null && snapshot.courseName!.isNotEmpty)
        snapshot.courseName,
    ].join(' · ');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _StatusCard(snapshot: snapshot),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brandSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.countdownLabel(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (snapshot.startsAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _formatFull(snapshot.startsAt!),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          snapshot.statusDetail,
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  static String _formatFull(DateTime value) {
    final local = value.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]} · $hour:$minute $suffix';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot});

  final LiveLobbySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final live = snapshot.sessionStatus == LiveSessionStatus.live;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: live
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.brandSoft,
        ),
      ),
      child: Row(
        children: [
          Icon(
            live ? Icons.sensors_rounded : Icons.meeting_room_outlined,
            color: live ? AppColors.accent : AppColors.brand,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              snapshot.statusLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: live ? AppColors.accent : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
