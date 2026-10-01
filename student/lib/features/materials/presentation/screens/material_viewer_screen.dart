import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/share/pragyu_copy.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/materials/data/materials_repository.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/materials/presentation/widgets/pdf_document_viewer.dart';
import 'package:student_mobile/features/media/presentation/widgets/network_media_player.dart';
import 'package:student_mobile/features/notes_bookmarks/data/notes_bookmarks_repository.dart';
import 'package:student_mobile/features/notes_bookmarks/domain/notes_bookmarks_models.dart';

typedef ExternalLinkOpener = Future<bool> Function(String url);

/// S-28 Material viewer — in-app PDF/video preview with open/copy fallback.
class MaterialViewerScreen extends StatefulWidget {
  const MaterialViewerScreen({
    super.key,
    required this.args,
    this.materialsRepository,
    this.bookmarksRepository,
    this.openExternalUrl,
    this.embedInAppMedia = true,
  });

  final MaterialViewerArgs args;
  final MaterialsGateway? materialsRepository;
  final NotesBookmarksGateway? bookmarksRepository;
  final ExternalLinkOpener? openExternalUrl;
  final bool embedInAppMedia;

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  late final MaterialsGateway _materials =
      widget.materialsRepository ?? MaterialsRepository();
  late final NotesBookmarksGateway _bookmarks =
      widget.bookmarksRepository ?? NotesBookmarksRepository();

  bool _loading = true;
  bool _bookmarkBusy = false;
  String? _error;
  MaterialViewerSnapshot? _snapshot;
  String? _bookmarkId;

  bool get _canBookmark {
    final args = widget.args;
    if (args.isResourceMode) return true;
    // Study-library materials are not in learning_content_bookmarks yet.
    return false;
  }

  String get _bookmarkableType {
    final snapshot = _snapshot;
    final fromArgs = widget.args.resourceType;
    return ContentBookmark.typeForResource(
      snapshot?.typeLabel ?? fromArgs,
    );
  }

  String? get _bookmarkableId {
    final args = widget.args;
    if (args.isResourceMode) return args.resourceId?.trim();
    return null;
  }

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
      final snapshot = await _materials.loadMaterialViewer(widget.args);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      if (_canBookmark) {
        unawaited(_refreshBookmarkState());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to open this material. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _refreshBookmarkState() async {
    final id = _bookmarkableId;
    if (id == null || id.isEmpty) return;
    final type = _bookmarkableType;
    try {
      final library = await _bookmarks.loadLibrary();
      if (!mounted) return;
      ContentBookmark? match;
      for (final bookmark in library.bookmarks) {
        if (bookmark.matches(type: type, id: id)) {
          match = bookmark;
          break;
        }
      }
      // Also match generic "resource" if type was normalized later.
      if (match == null && type != 'resource') {
        for (final bookmark in library.bookmarks) {
          if (bookmark.matches(type: 'resource', id: id)) {
            match = bookmark;
            break;
          }
        }
      }
      setState(() => _bookmarkId = match?.id);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _toggleBookmark() async {
    final id = _bookmarkableId;
    if (!_canBookmark || id == null || id.isEmpty || _bookmarkBusy) return;

    setState(() => _bookmarkBusy = true);
    try {
      final existingId = _bookmarkId;
      if (existingId != null && existingId.isNotEmpty) {
        await _bookmarks.removeBookmark(existingId);
        if (!mounted) return;
        setState(() {
          _bookmarkId = null;
          _bookmarkBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from bookmarks'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final saved = await _bookmarks.addBookmark(
        bookmarkableType: _bookmarkableType,
        bookmarkableId: id,
        title: _snapshot?.title ?? widget.args.title,
      );
      if (!mounted) return;
      setState(() {
        _bookmarkId = saved.id;
        _bookmarkBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved to bookmarks'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.notesBookmarks);
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _bookmarkBusy = false);
      final message = error is ApiException
          ? error.message
          : 'Unable to update bookmark. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyLink() async {
    final url = _snapshot?.openUrl?.trim();
    if (url == null || url.isEmpty) return;
    await copyPragyuText(
      context,
      text: url,
      message: PragyuCopyMessages.linkCopied,
    );
  }

  Future<void> _openLink() async {
    final url = _snapshot?.openUrl?.trim();
    if (url == null || url.isEmpty) return;

    final opener = widget.openExternalUrl ?? _defaultOpenUrl;
    final ok = await opener(url);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the link on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<bool> _defaultOpenUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Material');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
          actions: [
            if (_canBookmark)
              IconButton(
                tooltip: _bookmarkId == null
                    ? 'Save bookmark'
                    : 'Remove bookmark',
                onPressed: _snapshot == null || _bookmarkBusy
                    ? null
                    : _toggleBookmark,
                icon: _bookmarkBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _bookmarkId == null
                            ? Icons.bookmark_border_rounded
                            : Icons.bookmark_rounded,
                      ),
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          snapshot.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${snapshot.typeLabel} · ${snapshot.accessLabel}',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        if (widget.embedInAppMedia && snapshot.canPreviewInApp && snapshot.isPdf)
          PdfDocumentViewer(url: snapshot.openUrl!)
        else if (widget.embedInAppMedia &&
            snapshot.canPreviewInApp &&
            snapshot.isStreamableMedia)
          NetworkMediaPlayer(url: snapshot.openUrl!)
        else
          _ViewerFallback(
            locked: snapshot.isLocked,
            hasLink: snapshot.hasOpenableLink,
            typeLabel: snapshot.typeLabel,
            needsExternalOpen: snapshot.needsExternalOpen,
            previewAvailableButDisabled:
                snapshot.canPreviewInApp && !widget.embedInAppMedia,
          ),
        const SizedBox(height: 16),
        if (snapshot.isLocked)
          Text(
            snapshot.errorMessage ??
                'This material is locked for your enrollment.',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          )
        else if (!snapshot.hasOpenableLink)
          const Text(
            'No openable file or link is attached yet. Ask your institute if you expected content here.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          )
        else ...[
          if (snapshot.needsExternalOpen) ...[
            Text(
              'In-app preview isn’t available for ${snapshot.typeLabel.toLowerCase()} files. Open it in another app or browser.',
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openLink,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(
                snapshot.needsExternalOpen
                    ? 'Open externally'
                    : snapshot.isPdf
                        ? 'Open PDF'
                        : snapshot.isStreamableMedia
                            ? 'Open media'
                            : 'Open',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy link'),
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
          const SizedBox(height: 14),
          SelectableText(
            snapshot.openUrl!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _ViewerFallback extends StatelessWidget {
  const _ViewerFallback({
    required this.locked,
    required this.hasLink,
    required this.needsExternalOpen,
    required this.previewAvailableButDisabled,
    this.typeLabel = 'Material',
  });

  final bool locked;
  final bool hasLink;
  final bool needsExternalOpen;
  final bool previewAvailableButDisabled;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final kind = typeLabel.trim().isEmpty ? 'Material' : typeLabel.trim();
    final IconData icon;
    final String title;
    final String body;

    if (locked) {
      icon = Icons.lock_outline_rounded;
      title = 'Locked material';
      body = 'Enrollment or purchase is required to open this file.';
    } else if (!hasLink) {
      icon = Icons.insert_drive_file_outlined;
      title = 'No file attached';
      body = 'Nothing to open yet for this ${kind.toLowerCase()}.';
    } else if (needsExternalOpen) {
      icon = Icons.open_in_new_rounded;
      title = 'Can’t preview in app';
      body = '$kind files open outside Pragyu — use Open externally below.';
    } else if (previewAvailableButDisabled) {
      icon = Icons.play_circle_outline_rounded;
      title = 'Open to view';
      body = 'Use Open externally below to view this ${kind.toLowerCase()}.';
    } else {
      icon = Icons.description_outlined;
      title = 'Preview unavailable';
      body = 'Use Open externally below to view this file.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 42,
            color: locked ? AppColors.muted : AppColors.brand,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
