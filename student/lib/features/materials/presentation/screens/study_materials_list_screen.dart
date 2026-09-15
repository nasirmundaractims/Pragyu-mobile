import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/materials/data/materials_repository.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';

/// S-27 Study materials list — PDFs / notes for a course (or all enrollments).
class StudyMaterialsListScreen extends StatefulWidget {
  const StudyMaterialsListScreen({
    super.key,
    this.args = const StudyMaterialsListArgs(),
    this.materialsRepository,
  });

  final StudyMaterialsListArgs args;
  final MaterialsGateway? materialsRepository;

  @override
  State<StudyMaterialsListScreen> createState() =>
      _StudyMaterialsListScreenState();
}

class _StudyMaterialsListScreenState extends State<StudyMaterialsListScreen> {
  late final MaterialsGateway _materials =
      widget.materialsRepository ?? MaterialsRepository();

  bool _loading = true;
  String? _error;
  StudyMaterialsSnapshot? _snapshot;

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
      final snapshot = await _materials.loadMaterials(
        courseId: widget.args.courseId,
        courseTitle: widget.args.courseTitle,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load study materials. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openMaterial(StudyMaterial material) {
    if (material.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${material.title} is locked. Enroll or unlock to open.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.materialViewer,
      arguments: MaterialViewerArgs(
        materialId: material.id,
        title: material.title,
        externalUrl: material.externalUrl,
        mediaFileId: material.mediaFileId,
        resourceType: material.materialType.name,
        seed: material,
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
          title: const Text('Study materials'),
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
    final courseTitle = widget.args.courseTitle?.trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          courseTitle != null && courseTitle.isNotEmpty
              ? 'PDFs and notes for $courseTitle.'
              : 'PDFs and notes across your enrollments.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        if (snapshot.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text(
              'No study materials published yet.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          )
        else
          ...snapshot.items.map(_tile),
      ],
    );
  }

  Widget _tile(StudyMaterial material) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openMaterial(material),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brandSoft),
            ),
            child: Row(
              children: [
                Icon(
                  _iconFor(material.materialType),
                  color: material.isLocked ? AppColors.muted : AppColors.brand,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: material.isLocked
                              ? AppColors.muted
                              : AppColors.ink,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        material.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _TypeChip(label: material.typeLabel),
                if (material.isLocked) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ] else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(StudyMaterialKind type) {
    switch (type) {
      case StudyMaterialKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case StudyMaterialKind.notes:
        return Icons.notes_rounded;
      case StudyMaterialKind.presentation:
        return Icons.slideshow_outlined;
      case StudyMaterialKind.other:
        return Icons.description_outlined;
    }
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
