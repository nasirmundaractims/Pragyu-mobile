import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/notes_bookmarks/data/notes_bookmarks_repository.dart';
import 'package:student_mobile/features/notes_bookmarks/domain/notes_bookmarks_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// S-64 Notes & bookmarks — notes, content bookmarks, AI feedback library.
class NotesBookmarksScreen extends StatefulWidget {
  const NotesBookmarksScreen({
    super.key,
    this.libraryRepository,
  });

  final NotesBookmarksGateway? libraryRepository;

  @override
  State<NotesBookmarksScreen> createState() => _NotesBookmarksScreenState();
}

class _NotesBookmarksScreenState extends State<NotesBookmarksScreen> {
  late final NotesBookmarksGateway _repo =
      widget.libraryRepository ?? NotesBookmarksRepository();

  bool _loading = true;
  bool _savingNote = false;
  String? _busyId;
  String? _error;
  NotesBookmarksSnapshot? _snapshot;
  NotesHubSegment _segment = NotesHubSegment.notes;
  String _query = '';

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
      final snapshot = await _repo.loadLibrary();
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
            : 'Unable to load notes & bookmarks.';
      });
    }
  }

  Future<void> _promptCreateNote() async {
    final result = await showDialog<({String title, String body})>(
      context: context,
      builder: (context) => const _NewNoteDialog(),
    );
    if (result == null || result.body.isEmpty) return;

    setState(() {
      _savingNote = true;
      _error = null;
    });
    try {
      final note = await _repo.createNote(
        body: result.body,
        title: result.title.isEmpty ? null : result.title,
      );
      if (!mounted) return;
      final snapshot = _snapshot ?? const NotesBookmarksSnapshot();
      setState(() {
        _savingNote = false;
        _segment = NotesHubSegment.notes;
        _snapshot = snapshot.copyWith(notes: [note, ...snapshot.notes]);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingNote = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Unable to save note.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteNote(StudyNote note) async {
    setState(() => _busyId = note.id);
    try {
      await _repo.deleteNote(note.id);
      if (!mounted) return;
      final snapshot = _snapshot;
      if (snapshot == null) return;
      setState(() {
        _busyId = null;
        _snapshot = snapshot.copyWith(
          notes: snapshot.notes.where((n) => n.id != note.id).toList(),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Unable to delete note.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeBookmark(ContentBookmark bookmark) async {
    setState(() => _busyId = bookmark.id);
    try {
      await _repo.removeBookmark(bookmark.id);
      if (!mounted) return;
      final snapshot = _snapshot;
      if (snapshot == null) return;
      setState(() {
        _busyId = null;
        _snapshot = snapshot.copyWith(
          bookmarks:
              snapshot.bookmarks.where((b) => b.id != bookmark.id).toList(),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to remove bookmark.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openBookmark(ContentBookmark bookmark) {
    if (bookmark.isLesson && bookmark.bookmarkableId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        AppRoutes.lessonPlayer,
        arguments: LessonDetailArgs(
          lessonId: bookmark.bookmarkableId,
          title: bookmark.title,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved ${bookmark.typeLabel.toLowerCase()} bookmark'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFeedback(FeedbackReportItem item) {
    Navigator.of(context).pushNamed(
      AppRoutes.resultFeedback,
      arguments: ResultFeedbackArgs(submissionId: item.submissionId),
    );
  }

  List<StudyNote> get _notes {
    final q = _query.trim().toLowerCase();
    final items = _snapshot?.notes ?? const <StudyNote>[];
    if (q.isEmpty) return items;
    return items
        .where(
          (n) =>
              n.displayTitle.toLowerCase().contains(q) ||
              n.body.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  List<ContentBookmark> get _bookmarks {
    final q = _query.trim().toLowerCase();
    final items = _snapshot?.bookmarks ?? const <ContentBookmark>[];
    if (q.isEmpty) return items;
    return items
        .where(
          (b) =>
              b.displayTitle.toLowerCase().contains(q) ||
              b.typeLabel.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  List<FeedbackReportItem> get _feedback {
    final q = _query.trim().toLowerCase();
    final items = _snapshot?.feedback ?? const <FeedbackReportItem>[];
    if (q.isEmpty) return items;
    return items
        .where((f) => f.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Notes & Bookmarks'),
          actions: [
            IconButton(
              tooltip: 'Past results',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.pastResults),
              icon: const Icon(Icons.assignment_outlined),
            ),
          ],
        ),
        floatingActionButton: _segment == NotesHubSegment.notes
            ? FloatingActionButton.extended(
                onPressed: _savingNote ? null : _promptCreateNote,
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                icon: _savingNote
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.note_add_outlined),
                label: Text(_savingNote ? 'Saving…' : 'New note'),
              )
            : null,
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
                              notes: snapshot?.notes.length ?? 0,
                              bookmarks: snapshot?.bookmarks.length ?? 0,
                              feedback: snapshot?.feedback.length ?? 0,
                              latestPercent: snapshot?.latestFeedbackPercent,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search library…',
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
                            SegmentedButton<NotesHubSegment>(
                              segments: const [
                                ButtonSegment(
                                  value: NotesHubSegment.notes,
                                  label: Text('Notes'),
                                  icon: Icon(Icons.sticky_note_2_outlined),
                                ),
                                ButtonSegment(
                                  value: NotesHubSegment.bookmarks,
                                  label: Text('Saved'),
                                  icon: Icon(Icons.bookmark_outline),
                                ),
                                ButtonSegment(
                                  value: NotesHubSegment.feedback,
                                  label: Text('AI reports'),
                                  icon: Icon(Icons.auto_awesome),
                                ),
                              ],
                              selected: {_segment},
                              onSelectionChanged: (value) {
                                setState(() => _segment = value.first);
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_segment == NotesHubSegment.notes)
                              _NotesList(
                                notes: _notes,
                                busyId: _busyId,
                                onDelete: _deleteNote,
                              )
                            else if (_segment == NotesHubSegment.bookmarks)
                              _BookmarksList(
                                bookmarks: _bookmarks,
                                busyId: _busyId,
                                onOpen: _openBookmark,
                                onRemove: _removeBookmark,
                              )
                            else
                              _FeedbackList(
                                items: _feedback,
                                onOpen: _openFeedback,
                              ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _NewNoteDialog extends StatefulWidget {
  const _NewNoteDialog();

  @override
  State<_NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<_NewNoteDialog> {
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Note',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              (
                title: _title.text.trim(),
                body: _body.text.trim(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
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
          colors: [Color(0xFFFFF8EF), Color(0xFFF3F0FF)],
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
            'STUDY LIBRARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFFB86E00),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Notes, bookmarks & feedback',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Keep study notes, saved lessons, and AI evaluation reports in one place.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.notes,
    required this.bookmarks,
    required this.feedback,
    this.latestPercent,
  });

  final int notes;
  final int bookmarks;
  final int feedback;
  final double? latestPercent;

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
                label: 'Notes',
                value: '$notes',
                hint: 'Personal study notes',
                color: const Color(0xFFB86E00),
                bg: const Color(0xFFFFF4E5),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Bookmarks',
                value: '$bookmarks',
                hint: 'Saved content',
                color: const Color(0xFF6B4E9B),
                bg: const Color(0xFFF0EBFF),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Feedback',
                value: '$feedback',
                hint: 'Evaluated reports',
                color: AppColors.brand,
                bg: AppColors.brandSoft,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Latest score',
                value: latestPercent == null
                    ? '—'
                    : '${latestPercent!.round()}%',
                hint: 'Most recent evaluation',
                color: AppColors.success,
                bg: const Color(0xFFE7F8EF),
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

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.busyId,
    required this.onDelete,
  });

  final List<StudyNote> notes;
  final String? busyId;
  final ValueChanged<StudyNote> onDelete;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const _EmptyCard(
        icon: Icons.sticky_note_2_outlined,
        title: 'No notes yet',
        body: 'Capture key points from lessons and mentor chats with New note.',
      );
    }
    return Column(
      children: [
        for (final note in notes) ...[
          _LibraryCard(
            badge: 'NOTE',
            badgeColor: const Color(0xFFB86E00),
            badgeBg: const Color(0xFFFFF4E5),
            title: note.displayTitle,
            body: note.body,
            meta: note.updatedAt == null
                ? null
                : note.updatedAt!.toLocal().toIso8601String().substring(0, 10),
            trailing: IconButton(
              tooltip: 'Delete',
              onPressed: busyId == note.id ? null : () => onDelete(note),
              icon: busyId == note.id
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BookmarksList extends StatelessWidget {
  const _BookmarksList({
    required this.bookmarks,
    required this.busyId,
    required this.onOpen,
    required this.onRemove,
  });

  final List<ContentBookmark> bookmarks;
  final String? busyId;
  final ValueChanged<ContentBookmark> onOpen;
  final ValueChanged<ContentBookmark> onRemove;

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return const _EmptyCard(
        icon: Icons.bookmark_outline,
        title: 'No bookmarks yet',
        body: 'Bookmark lessons, PDFs, and videos while learning to find them here.',
      );
    }
    return Column(
      children: [
        for (final bookmark in bookmarks) ...[
          _LibraryCard(
            badge: bookmark.typeLabel.toUpperCase(),
            badgeColor: const Color(0xFF6B4E9B),
            badgeBg: const Color(0xFFF0EBFF),
            title: bookmark.displayTitle,
            body: 'Saved ${bookmark.typeLabel.toLowerCase()}',
            meta: bookmark.createdAt == null
                ? null
                : bookmark.createdAt!
                    .toLocal()
                    .toIso8601String()
                    .substring(0, 10),
            onTap: () => onOpen(bookmark),
            trailing: IconButton(
              tooltip: 'Remove',
              onPressed:
                  busyId == bookmark.id ? null : () => onRemove(bookmark),
              icon: busyId == bookmark.id
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_remove_outlined),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({
    required this.items,
    required this.onOpen,
  });

  final List<FeedbackReportItem> items;
  final ValueChanged<FeedbackReportItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(
        icon: Icons.auto_awesome,
        title: 'No feedback yet',
        body:
            'After you submit an answer and it is evaluated, strengths, gaps, and rewrite tips appear here.',
      );
    }
    return Column(
      children: [
        for (final item in items) ...[
          _LibraryCard(
            badge: 'FEEDBACK',
            badgeColor: AppColors.brand,
            badgeBg: AppColors.brandSoft,
            title: item.title,
            body:
                'Attempt ${item.attemptNumber} · ${item.scoreLabel} · ${item.percentLabel}',
            meta: item.evaluatedAt == null
                ? null
                : item.evaluatedAt!
                    .toLocal()
                    .toIso8601String()
                    .substring(0, 10),
            onTap: () => onOpen(item),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
    required this.title,
    required this.body,
    this.meta,
    this.onTap,
    this.trailing,
  });

  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final String title;
  final String body;
  final String? meta;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brandSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        meta!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

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
          Icon(icon, size: 34, color: AppColors.brand),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
