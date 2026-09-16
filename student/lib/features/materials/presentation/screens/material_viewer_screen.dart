import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/materials/data/materials_repository.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/materials/presentation/widgets/pdf_document_viewer.dart';
import 'package:student_mobile/features/media/presentation/widgets/network_media_player.dart';

typedef ExternalLinkOpener = Future<bool> Function(String url);

/// S-28 Material viewer — in-app PDF/video preview with open/copy fallback.
class MaterialViewerScreen extends StatefulWidget {
  const MaterialViewerScreen({
    super.key,
    required this.args,
    this.materialsRepository,
    this.openExternalUrl,
    this.embedInAppMedia = true,
  });

  final MaterialViewerArgs args;
  final MaterialsGateway? materialsRepository;
  final ExternalLinkOpener? openExternalUrl;
  final bool embedInAppMedia;

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  late final MaterialsGateway _materials =
      widget.materialsRepository ?? MaterialsRepository();

  bool _loading = true;
  String? _error;
  MaterialViewerSnapshot? _snapshot;

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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to open this material. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _copyLink() async {
    final url = _snapshot?.openUrl?.trim();
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied.'),
        behavior: SnackBarBehavior.floating,
      ),
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
        if (widget.embedInAppMedia &&
            !snapshot.isLocked &&
            snapshot.hasOpenableLink &&
            snapshot.isPdf)
          PdfDocumentViewer(url: snapshot.openUrl!)
        else if (widget.embedInAppMedia &&
            !snapshot.isLocked &&
            snapshot.hasOpenableLink &&
            snapshot.isStreamableMedia)
          NetworkMediaPlayer(url: snapshot.openUrl!)
        else
          _ViewerStub(
            locked: snapshot.isLocked,
            hasLink: snapshot.hasOpenableLink,
            typeLabel: snapshot.typeLabel,
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
            'No openable file or link is attached yet.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          )
        else ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openLink,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open'),
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

class _ViewerStub extends StatelessWidget {
  const _ViewerStub({
    required this.locked,
    required this.hasLink,
    this.typeLabel = 'Material',
  });

  final bool locked;
  final bool hasLink;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              locked
                  ? Icons.lock_outline_rounded
                  : hasLink
                      ? Icons.description_outlined
                      : Icons.insert_drive_file_outlined,
              size: 42,
              color: locked ? AppColors.muted : AppColors.brand,
            ),
            const SizedBox(height: 10),
            Text(
              locked
                  ? 'Locked material'
                  : hasLink
                      ? 'Preview unavailable — use Open below'
                      : 'No file attached',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
