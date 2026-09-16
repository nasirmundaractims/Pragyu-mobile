import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/media/presentation/widgets/network_media_player.dart';

/// S-26 Recorded lecture player — in-app playback, progress, mark complete.
class RecordedLectureScreen extends StatefulWidget {
  const RecordedLectureScreen({
    super.key,
    required this.args,
    this.lecturesRepository,
    this.embedInAppMedia = true,
  });

  final RecordedLectureArgs args;
  final LecturesGateway? lecturesRepository;
  final bool embedInAppMedia;

  @override
  State<RecordedLectureScreen> createState() => _RecordedLectureScreenState();
}

class _RecordedLectureScreenState extends State<RecordedLectureScreen> {
  late final LecturesGateway _lectures =
      widget.lecturesRepository ?? LecturesRepository();

  bool _loading = true;
  bool _loadingPlayback = false;
  bool _completing = false;
  String? _error;
  RecordedLectureSnapshot? _snapshot;
  LecturePlaybackInfo? _playback;
  DateTime? _lastProgressSent;

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
      final snapshot = await _lectures.loadRecordedLecture(widget.args.lectureId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      if (widget.embedInAppMedia && !snapshot.isLocked && snapshot.hasVideo) {
        await _loadPlayback();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load this lecture. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _loadPlayback() async {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.isLocked || _loadingPlayback) return;

    setState(() => _loadingPlayback = true);
    try {
      final playback = await _lectures.loadPlayback(snapshot.lectureId);
      if (!mounted) return;
      setState(() {
        _playback = playback;
        _loadingPlayback = false;
      });
      if (playback.bestUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No playable video link is available yet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPlayback = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to fetch playback link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markComplete() async {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.isCompleted || _completing) return;

    setState(() => _completing = true);
    try {
      final updated = await _lectures.completeRecordedLecture(snapshot.lectureId);
      if (!mounted) return;
      setState(() {
        _snapshot = updated;
        _completing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lecture marked complete.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _completing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark complete. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyPlaybackUrl() async {
    final url = _playback?.bestUrl;
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Playback link copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Lecture');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Recorded lecture'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _load,
            child: _buildBody(title),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget? _buildBottomBar() {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.isLocked) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: snapshot.isCompleted || _completing ? null : _markComplete,
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
          child: _completing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                )
              : Text(snapshot.isCompleted ? 'Completed' : 'Mark complete'),
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
    final playback = _playback;
    final url = playback?.bestUrl;

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
        if (snapshot.subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            snapshot.subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (widget.embedInAppMedia && !snapshot.isLocked && url != null)
          NetworkMediaPlayer(
            url: url,
            onPosition: (position) {
              final now = DateTime.now();
              if (_lastProgressSent != null &&
                  now.difference(_lastProgressSent!) <
                      const Duration(seconds: 15)) {
                return;
              }
              _lastProgressSent = now;
              final total = snapshot.durationSeconds ??
                  _playback?.durationSeconds ??
                  0;
              final percent = total > 0
                  ? ((position.inSeconds / total) * 100).round().clamp(0, 100)
                  : null;
              _lectures.reportPlaybackProgress(
                lectureId: snapshot.lectureId,
                positionSeconds: position.inSeconds,
                progressPercent: percent,
              );
            },
          )
        else
          _PlayerStub(
            locked: snapshot.isLocked,
            hasVideo: snapshot.hasVideo,
            urlLoaded: url != null,
          ),
        const SizedBox(height: 14),
        _ProgressCard(snapshot: snapshot),
        const SizedBox(height: 14),
        if (snapshot.isLocked)
          const Text(
            'This recording is locked for your enrollment.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          )
        else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadingPlayback ? null : _loadPlayback,
              icon: _loadingPlayback
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(
                url == null ? 'Get playback link' : 'Refresh playback link',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.brandSoft),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (url != null) ...[
            const SizedBox(height: 12),
            Container(
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
                  const Text(
                    'Playback URL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    url,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _copyPlaybackUrl,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy link'),
                  ),
                  if (playback!.qualities.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Qualities: ${playback.qualities.join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (playback.playbackSpeeds.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Speeds: ${playback.playbackSpeeds.map((s) => '${s}x').join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
        if (snapshot.description != null &&
            snapshot.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'About',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.description!.trim(),
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerStub extends StatelessWidget {
  const _PlayerStub({
    required this.locked,
    required this.hasVideo,
    required this.urlLoaded,
  });

  final bool locked;
  final bool hasVideo;
  final bool urlLoaded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2433),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            locked
                ? Icons.lock_outline_rounded
                : Icons.ondemand_video_outlined,
            color: Colors.white70,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            locked
                ? 'Locked'
                : urlLoaded
                    ? 'Link ready'
                    : hasVideo
                        ? 'Recorded lecture'
                        : 'No video yet',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            locked
                ? 'Enrollment access required.'
                : 'Tap Get playback link to start watching.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.snapshot});

  final RecordedLectureSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final fraction = (snapshot.progressPercent / 100).clamp(0.0, 1.0);
    return Container(
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
          Row(
            children: [
              Text(
                snapshot.isCompleted
                    ? 'Completed'
                    : '${snapshot.progressPercent}% watched',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                snapshot.durationLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              color: AppColors.accent,
              backgroundColor: AppColors.brandSoft,
            ),
          ),
        ],
      ),
    );
  }
}
