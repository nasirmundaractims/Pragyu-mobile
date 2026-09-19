import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/media/presentation/widgets/network_media_player.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

/// S-22 Lesson / content player — redesigned from Pragyu Lesson reference.
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

enum _LessonTab { video, notes, resources, practice, discussion }

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _green = Color(0xFF22A06B);
  static const _pageBg = Color(0xFFF7F9FC);

  late final LearnGateway _learn =
      widget.learnRepository ?? LearnRepository();

  bool _loading = true;
  bool _completing = false;
  String? _error;
  LessonDetailSnapshot? _snapshot;
  CourseDetailSnapshot? _course;
  _LessonTab _tab = _LessonTab.video;
  bool _chapterExpanded = true;

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
      CourseDetailSnapshot? course;
      final courseId = snapshot.courseId ?? widget.args.courseId;
      if (courseId != null && courseId.trim().isNotEmpty) {
        try {
          course = await _learn.loadCourseDetail(
            CourseDetailArgs(courseId: courseId, title: null),
          );
        } catch (_) {
          course = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _course = course;
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

  Future<void> _markComplete({bool goNext = false}) async {
    final snapshot = _snapshot;
    if (snapshot == null || _completing) return;
    if (!snapshot.progress.isCompleted) {
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
        return;
      }
    }
    if (goNext) {
      final next = _nextLesson;
      if (next != null) {
        _openLesson(next);
      }
    }
  }

  void _openLesson(CourseLesson lesson) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.lessonPlayer,
      arguments: LessonDetailArgs(
        lessonId: lesson.id,
        courseId: _snapshot?.courseId ?? widget.args.courseId,
        title: lesson.title,
      ),
    );
  }

  void _openResource(LessonResource resource) {
    if (resource.isStreamableMedia && resource.hasPlayableUrl) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _pageBg,
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
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
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
        backgroundColor: _pageBg,
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
                    softWrap: true,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    softWrap: true,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      height: 1.5,
                      color: _ink,
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

  List<CourseLesson> get _flatLessons {
    final course = _course;
    if (course == null) return const [];
    final lessons = <CourseLesson>[];
    for (final module in course.modules) {
      lessons.addAll(module.lessons);
    }
    return lessons;
  }

  CourseModule? get _currentModule {
    final course = _course;
    final lessonId = _snapshot?.lessonId;
    if (course == null || lessonId == null) return null;
    for (final module in course.modules) {
      for (final lesson in module.lessons) {
        if (lesson.id == lessonId) return module;
      }
    }
    return course.modules.isNotEmpty ? course.modules.first : null;
  }

  CourseLesson? get _previousLesson {
    final lessons = _flatLessons;
    final id = _snapshot?.lessonId;
    if (id == null || lessons.isEmpty) return null;
    final index = lessons.indexWhere((l) => l.id == id);
    if (index <= 0) return null;
    return lessons[index - 1];
  }

  CourseLesson? get _nextLesson {
    final lessons = _flatLessons;
    final id = _snapshot?.lessonId;
    if (id == null || lessons.isEmpty) return null;
    final index = lessons.indexWhere((l) => l.id == id);
    if (index < 0 || index >= lessons.length - 1) return null;
    return lessons[index + 1];
  }

  int get _lessonIndex {
    final module = _currentModule;
    final id = _snapshot?.lessonId;
    if (module == null || id == null) return 1;
    final index = module.lessons.indexWhere((l) => l.id == id);
    return index < 0 ? 1 : index + 1;
  }

  LessonResource? get _primaryVideo {
    final resources = _snapshot?.resources ?? const <LessonResource>[];
    for (final resource in resources) {
      if (resource.isStreamableMedia && resource.hasPlayableUrl) {
        return resource;
      }
    }
    return null;
  }

  List<String> get _objectives {
    final summary = (_snapshot?.summary ?? '').trim();
    if (summary.isEmpty) {
      return const [
        'Understand the key ideas covered in this lesson',
        'Review examples and explanations carefully',
        'Practice applying concepts in your own words',
      ];
    }
    final parts = summary
        .split(RegExp(r'[\n•]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .take(4)
        .toList();
    // Avoid repeating a short summary already shown in "About".
    if (parts.length <= 1 && summary.length < 120) {
      return const [
        'Understand the key ideas covered in this lesson',
        'Review examples and explanations carefully',
        'Practice applying concepts in your own words',
      ];
    }
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Lesson');
    final subtitle = _snapshot?.hierarchyLabel;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _ink,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Bookmark',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.notesBookmarks),
              icon: const Icon(Icons.bookmark_border_rounded),
            ),
            IconButton(
              tooltip: 'Download',
              onPressed: () {
                final pdf = (_snapshot?.resources ?? const <LessonResource>[])
                    .where(
                      (r) =>
                          r.resourceType.toLowerCase().contains('pdf') ||
                          r.isDownloadable,
                    )
                    .cast<LessonResource?>()
                    .firstWhere((r) => r != null, orElse: () => null);
                if (pdf != null) {
                  _openResource(pdf);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No downloadable resource yet.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download_outlined),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'refresh') _load();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: _blue,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
        bottomNavigationBar: _snapshot == null
            ? null
            : _BottomBar(
                previous: _previousLesson,
                completing: _completing,
                completed: _snapshot!.progress.isCompleted,
                onPrevious: _previousLesson == null
                    ? null
                    : () => _openLesson(_previousLesson!),
                onComplete: () => _markComplete(goNext: true),
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
          Center(child: CircularProgressIndicator(color: _blue)),
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
            style: const TextStyle(color: Color(0xFFC0392B), height: 1.45),
          ),
        ],
      );
    }

    final snapshot = _snapshot!;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 720;
    final padH = size.width < 360 ? 14.0 : 18.0;
    final video = _primaryVideo;
    final module = _currentModule;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padH, 8, padH, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFC0392B), height: 1.4),
          ),
          const SizedBox(height: 10),
        ],
        _VideoHero(video: video),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                snapshot.title,
                softWrap: true,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: size.width < 360 ? 20 : 22,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusPill(label: snapshot.progress.statusLabel),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            if (module != null)
              _MetaChip(
                icon: Icons.description_outlined,
                label:
                    'Lesson $_lessonIndex of ${module.lessons.isEmpty ? 1 : module.lessons.length}',
              ),
            if (snapshot.estimatedMinutes != null)
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: '${snapshot.estimatedMinutes} minutes',
              ),
            _MetaChip(
              icon: Icons.bar_chart_rounded,
              label: '${snapshot.progress.progressPercent}%',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _LessonTabs(
          selected: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 16),
        if (_tab == _LessonTab.video)
          _VideoTabContent(
            narrow: narrow,
            snapshot: snapshot,
            module: module,
            chapterExpanded: _chapterExpanded,
            onToggleChapter: () =>
                setState(() => _chapterExpanded = !_chapterExpanded),
            onOpenLesson: _openLesson,
            objectives: _objectives,
            nextLesson: _nextLesson,
            onOpenResource: _openResource,
            onKeyPoints: () => _showKeyPoints(snapshot),
            onNotes: () =>
                Navigator.of(context).pushNamed(AppRoutes.notesBookmarks),
          )
        else if (_tab == _LessonTab.notes)
          _NotesPane(content: snapshot.contentText, summary: snapshot.summary)
        else if (_tab == _LessonTab.resources)
          _ResourcesPane(
            resources: snapshot.resources,
            onOpen: _openResource,
          )
        else if (_tab == _LessonTab.practice)
          _PracticePane(
            assessmentId: snapshot.assessmentId,
            onOpenAssessment: () {
              final id = snapshot.assessmentId?.trim();
              if (id == null || id.isEmpty) {
                Navigator.of(context).pushNamed(AppRoutes.weakTopics);
                return;
              }
              Navigator.of(context).pushNamed(
                AppRoutes.assessmentDetail,
                arguments: AssessmentDetailArgs(assessmentId: id),
              );
            },
          )
        else
          const _DiscussionPane(),
        ],
      ),
    );
  }

  void _showKeyPoints(LessonDetailSnapshot snapshot) {
    final text = (snapshot.summary ?? snapshot.contentText).trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Key Points',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  text.isEmpty
                      ? 'Key points will appear when lesson notes are available.'
                      : text,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    height: 1.5,
                    color: _ink,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoHero extends StatelessWidget {
  const _VideoHero({required this.video});

  final LessonResource? video;

  @override
  Widget build(BuildContext context) {
    if (video != null && video!.hasPlayableUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: NetworkMediaPlayer(
          url: video!.externalUrl!,
          height: 210,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF152A52), Color(0xFF2F7BFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _PlayerGlowPainter()),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Lesson media will play here',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pragyu',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: _LessonPlayerScreenState._ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTabs extends StatelessWidget {
  const _LessonTabs({
    required this.selected,
    required this.onSelected,
  });

  final _LessonTab selected;
  final ValueChanged<_LessonTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <(_LessonTab, String)>[
      (_LessonTab.video, 'Video'),
      (_LessonTab.notes, 'Notes'),
      (_LessonTab.resources, 'Resources'),
      (_LessonTab.practice, 'Practice'),
      (_LessonTab.discussion, 'Discussion'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            InkWell(
              key: ValueKey('lesson-tab-${item.$1.name}'),
              onTap: () => onSelected(item.$1),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected == item.$1
                          ? _LessonPlayerScreenState._blue
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: selected == item.$1
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 14,
                    color: selected == item.$1
                        ? _LessonPlayerScreenState._blue
                        : _LessonPlayerScreenState._muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoTabContent extends StatelessWidget {
  const _VideoTabContent({
    required this.narrow,
    required this.snapshot,
    required this.module,
    required this.chapterExpanded,
    required this.onToggleChapter,
    required this.onOpenLesson,
    required this.objectives,
    required this.nextLesson,
    required this.onOpenResource,
    required this.onKeyPoints,
    required this.onNotes,
  });

  final bool narrow;
  final LessonDetailSnapshot snapshot;
  final CourseModule? module;
  final bool chapterExpanded;
  final VoidCallback onToggleChapter;
  final ValueChanged<CourseLesson> onOpenLesson;
  final List<String> objectives;
  final CourseLesson? nextLesson;
  final ValueChanged<LessonResource> onOpenResource;
  final VoidCallback onKeyPoints;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final timeline = _ChapterTimeline(
      module: module,
      currentLessonId: snapshot.lessonId,
      expanded: chapterExpanded,
      onToggle: onToggleChapter,
      onOpenLesson: onOpenLesson,
    );

    final details = _LessonDetailsColumn(
      snapshot: snapshot,
      objectives: objectives,
      nextLesson: nextLesson,
      onOpenNext: nextLesson == null ? null : () => onOpenLesson(nextLesson!),
      onOpenResource: onOpenResource,
      onKeyPoints: onKeyPoints,
      onNotes: onNotes,
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          details,
          const SizedBox(height: 14),
          timeline,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: timeline),
        const SizedBox(width: 14),
        Expanded(flex: 6, child: details),
      ],
    );
  }
}

class _ChapterTimeline extends StatelessWidget {
  const _ChapterTimeline({
    required this.module,
    required this.currentLessonId,
    required this.expanded,
    required this.onToggle,
    required this.onOpenLesson,
  });

  final CourseModule? module;
  final String currentLessonId;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<CourseLesson> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final lessons = module?.lessons ?? const <CourseLesson>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module?.title ?? 'This chapter',
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _LessonPlayerScreenState._ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: _LessonPlayerScreenState._muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _LessonPlayerScreenState._muted,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            if (lessons.isEmpty)
              const Text(
                'Lesson outline will appear when course structure is available.',
                softWrap: true,
                style: TextStyle(
                  color: _LessonPlayerScreenState._muted,
                  height: 1.4,
                ),
              )
            else
              ...lessons.asMap().entries.map((entry) {
                final index = entry.key;
                final lesson = entry.value;
                final active = lesson.id == currentLessonId;
                final done = lesson.isCompleted;
                return _TimelineRow(
                  index: index + 1,
                  lesson: lesson,
                  active: active,
                  done: done,
                  isLast: index == lessons.length - 1,
                  onTap: () => onOpenLesson(lesson),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.lesson,
    required this.active,
    required this.done,
    required this.isLast,
    required this.onTap,
  });

  final int index;
  final CourseLesson lesson;
  final bool active;
  final bool done;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: active
              ? _LessonPlayerScreenState._blueSoft
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: done
                          ? _LessonPlayerScreenState._green
                          : active
                              ? _LessonPlayerScreenState._blue
                              : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done
                            ? _LessonPlayerScreenState._green
                            : active
                                ? _LessonPlayerScreenState._blue
                                : const Color(0xFFCDD5E1),
                        width: 1.6,
                      ),
                    ),
                    child: Icon(
                      done
                          ? Icons.check_rounded
                          : active
                              ? Icons.play_arrow_rounded
                              : null,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 28,
                      margin: const EdgeInsets.only(top: 2),
                      color: done
                          ? _LessonPlayerScreenState._green.withValues(alpha: 0.45)
                          : const Color(0xFFE4EAF2),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. ${lesson.title}',
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: active
                          ? _LessonPlayerScreenState._blue
                          : _LessonPlayerScreenState._ink,
                      height: 1.25,
                    ),
                  ),
                  if (lesson.estimatedMinutes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.estimatedMinutes} min',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: _LessonPlayerScreenState._muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonDetailsColumn extends StatelessWidget {
  const _LessonDetailsColumn({
    required this.snapshot,
    required this.objectives,
    required this.nextLesson,
    required this.onOpenNext,
    required this.onOpenResource,
    required this.onKeyPoints,
    required this.onNotes,
  });

  final LessonDetailSnapshot snapshot;
  final List<String> objectives;
  final CourseLesson? nextLesson;
  final VoidCallback? onOpenNext;
  final ValueChanged<LessonResource> onOpenResource;
  final VoidCallback onKeyPoints;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final about = snapshot.contentText.isNotEmpty
        ? snapshot.contentText
        : (snapshot.summary ??
            'No lesson text yet. Open a resource below to continue.');
    final pdf = snapshot.resources
        .where(
          (r) =>
              r.resourceType.toLowerCase().contains('pdf') ||
              r.isDownloadable,
        )
        .cast<LessonResource?>()
        .firstWhere((r) => r != null, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'About this lesson',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: _LessonPlayerScreenState._ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          about,
          softWrap: true,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14.5,
            height: 1.55,
            color: _LessonPlayerScreenState._muted,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _LessonPlayerScreenState._blueSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _LessonPlayerScreenState._blue.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    color: _LessonPlayerScreenState._blue,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Learning Objectives',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w800,
                      color: _LessonPlayerScreenState._ink,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...objectives.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: _LessonPlayerScreenState._green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          softWrap: true,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            height: 1.35,
                            color: _LessonPlayerScreenState._ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 340;
            final cards = [
              _QuickActionCard(
                label: 'Download PDF Notes',
                icon: Icons.picture_as_pdf_outlined,
                background: const Color(0xFFF3E8FF),
                accent: const Color(0xFF7B5CFF),
                onTap: () {
                  if (pdf != null) {
                    onOpenResource(pdf);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No PDF notes attached yet.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              _QuickActionCard(
                label: 'View Key Points',
                icon: Icons.list_alt_rounded,
                background: const Color(0xFFE8F8EE),
                accent: _LessonPlayerScreenState._green,
                onTap: onKeyPoints,
              ),
              _QuickActionCard(
                label: 'Take Quick Notes',
                icon: Icons.edit_note_rounded,
                background: const Color(0xFFFFF0E4),
                accent: const Color(0xFFE67E22),
                onTap: onNotes,
              ),
            ];
            if (stack) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    SizedBox(width: double.infinity, child: card),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
        if (nextLesson != null) ...[
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onOpenNext,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4EAF2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Next Lesson',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _LessonPlayerScreenState._muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextLesson!.title,
                            softWrap: true,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _LessonPlayerScreenState._ink,
                            ),
                          ),
                          if (nextLesson!.estimatedMinutes != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${nextLesson!.estimatedMinutes} minutes',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: _LessonPlayerScreenState._muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: _LessonPlayerScreenState._blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.background,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesPane extends StatelessWidget {
  const _NotesPane({
    required this.content,
    required this.summary,
  });

  final String content;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final text = content.isNotEmpty
        ? content
        : (summary ?? 'No lesson notes available yet.');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Text(
        text,
        softWrap: true,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 15,
          height: 1.55,
          color: _LessonPlayerScreenState._ink,
        ),
      ),
    );
  }
}

class _ResourcesPane extends StatelessWidget {
  const _ResourcesPane({
    required this.resources,
    required this.onOpen,
  });

  final List<LessonResource> resources;
  final ValueChanged<LessonResource> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Resources',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _LessonPlayerScreenState._ink,
          ),
        ),
        const SizedBox(height: 10),
        if (resources.isEmpty)
          const Text(
            'No resources attached to this lesson.',
            softWrap: true,
            style: TextStyle(
              color: _LessonPlayerScreenState._muted,
              height: 1.45,
            ),
          )
        else
          ...resources.map(
            (resource) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ResourceTile(
                resource: resource,
                onTap: () => onOpen(resource),
              ),
            ),
          ),
      ],
    );
  }
}

class _PracticePane extends StatelessWidget {
  const _PracticePane({
    required this.assessmentId,
    required this.onOpenAssessment,
  });

  final String? assessmentId;
  final VoidCallback onOpenAssessment;

  @override
  Widget build(BuildContext context) {
    final hasAssessment =
        assessmentId != null && assessmentId!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasAssessment
                ? 'Practice questions are available for this lesson.'
                : 'Practice related weak topics to reinforce this lesson.',
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: _LessonPlayerScreenState._muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onOpenAssessment,
            style: FilledButton.styleFrom(
              backgroundColor: _LessonPlayerScreenState._blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(hasAssessment ? 'Open practice' : 'Open weak topics'),
          ),
        ],
      ),
    );
  }
}

class _DiscussionPane extends StatelessWidget {
  const _DiscussionPane();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: const Text(
        'Discussion for this lesson will appear here soon.',
        softWrap: true,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: _LessonPlayerScreenState._muted,
          height: 1.45,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.previous,
    required this.completing,
    required this.completed,
    required this.onPrevious,
    required this.onComplete,
  });

  final CourseLesson? previous;
  final bool completing;
  final bool completed;
  final VoidCallback? onPrevious;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x22001A3D),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Previous Lesson'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _LessonPlayerScreenState._blue,
                  side: const BorderSide(
                    color: _LessonPlayerScreenState._blue,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: completing ? null : onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: _LessonPlayerScreenState._blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB7C4D8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: completing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        completed ? 'Completed' : 'Mark complete',
                        softWrap: true,
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _LessonPlayerScreenState._muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: _LessonPlayerScreenState._muted,
            fontWeight: FontWeight.w600,
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
    final completed = label.toLowerCase().contains('complete');
    final inProgress = label.toLowerCase().contains('progress');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: completed || inProgress
            ? _LessonPlayerScreenState._green
            : const Color(0xFFE8EEF6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: completed || inProgress
              ? Colors.white
              : _LessonPlayerScreenState._muted,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4EAF2)),
          ),
          child: Row(
            children: [
              Icon(_icon, color: _LessonPlayerScreenState._blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                        color: _LessonPlayerScreenState._ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _LessonPlayerScreenState._muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _LessonPlayerScreenState._muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.75, size.height * 0.3),
          radius: size.width * 0.4,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.3),
      size.width * 0.4,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
