import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/media/presentation/widgets/network_media_player.dart';

/// S-22 Lesson / content player — text, in-app media resources, mark complete.
class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({
    super.key,
    required this.args,
    this.learnRepository,
  });

  final LessonDetailArgs args;
  final LearnGateway? learnRepository;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late final LearnGateway _learn =
      widget.learnRepository ?? LearnRepository();

  bool _loading = true;
  bool _completing = false;
  String? _error;
  LessonDetailSnapshot? _snapshot;

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
      final snapshot = await _learn.loadLesson(widget.args);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to open this lesson. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _markComplete() async {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.progress.isCompleted || _completing) {
      return;
    }
    setState(() => _completing = true);
    try {
      final progress = await _learn.completeLesson(snapshot.lessonId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot.copyWith(progress: progress);
        _completing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson marked complete.'),
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

  void _openResource(LessonResource resource) {
    if (resource.isStreamableMedia && resource.hasPlayableUrl) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  resource.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                NetworkMediaPlayer(url: resource.externalUrl!),
              ],
            ),
          );
        },
      );
      return;
    }

    final text = resource.contentText?.trim();
    if (text != null && text.isNotEmpty) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    resource.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.materialViewer,
      arguments: MaterialViewerArgs(
        resourceId: resource.id,
        title: resource.title,
        externalUrl: resource.externalUrl,
        resourceType: resource.resourceType,
        isDownloadable: resource.isDownloadable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Lesson');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
        bottomNavigationBar: _snapshot == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton(
                    onPressed: _snapshot!.progress.isCompleted || _completing
                        ? null
                        : _markComplete,
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
                        : Text(
                            _snapshot!.progress.isCompleted
                                ? 'Completed'
                                : 'Mark complete',
                          ),
                  ),
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
    final content = snapshot.contentText;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (snapshot.hierarchyLabel != null) ...[
          Text(
            snapshot.hierarchyLabel!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            _StatusPill(label: snapshot.progress.statusLabel),
            if (snapshot.estimatedMinutes != null) ...[
              const SizedBox(width: 8),
              Text(
                '${snapshot.estimatedMinutes} min',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            Text(
              '${snapshot.progress.progressPercent}%',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...snapshot.resources
            .where((r) => r.isStreamableMedia && r.hasPlayableUrl)
            .take(2)
            .map(
              (resource) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      resource.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    NetworkMediaPlayer(url: resource.externalUrl!),
                  ],
                ),
              ),
            ),
        if (content.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brandSoft),
            ),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: AppColors.ink,
              ),
            ),
          )
        else
          const Text(
            'No lesson text yet. Open a resource below to continue.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
        const SizedBox(height: 22),
        const Text(
          'Resources',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (snapshot.resources.isEmpty)
          const Text(
            'No resources attached to this lesson.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          )
        else
          ...snapshot.resources.map(
            (resource) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ResourceTile(
                resource: resource,
                onTap: () => _openResource(resource),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final completed = label == 'Completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFE6F5EE) : AppColors.brandSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: completed ? AppColors.success : AppColors.muted,
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.resource,
    required this.onTap,
  });

  final LessonResource resource;
  final VoidCallback onTap;

  IconData get _icon {
    switch (resource.resourceType.toLowerCase()) {
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'notes':
      case 'text':
        return Icons.notes_rounded;
      case 'audio':
        return Icons.headphones_outlined;
      default:
        return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      resource.typeLabel,
      if (resource.durationSeconds != null && resource.durationSeconds! > 0)
        '${(resource.durationSeconds! / 60).ceil()} min',
      if (resource.isDownloadable) 'Downloadable',
    ].join(' · ');

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
            children: [
              Icon(_icon, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
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
}
