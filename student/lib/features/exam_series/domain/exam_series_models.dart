/// S-67 Exam Series / Question Bank models.

class ExamSeriesDetailArgs {
  const ExamSeriesDetailArgs({
    required this.seriesId,
    this.title,
    this.organizationId,
    this.organizationName,
  });

  final String seriesId;
  final String? title;
  final String? organizationId;
  final String? organizationName;

  factory ExamSeriesDetailArgs.fromObject(Object? raw) {
    if (raw is ExamSeriesDetailArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return ExamSeriesDetailArgs(
        seriesId: map['seriesId']?.toString() ??
            map['series_id']?.toString() ??
            map['id']?.toString() ??
            '',
        title: map['title']?.toString(),
        organizationId: map['organizationId']?.toString() ??
            map['organization_id']?.toString(),
        organizationName: map['organizationName']?.toString() ??
            map['organization_name']?.toString(),
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return ExamSeriesDetailArgs(seriesId: raw);
    }
    return const ExamSeriesDetailArgs(seriesId: '');
  }
}

class ExamSeriesItem {
  const ExamSeriesItem({
    required this.id,
    required this.assessmentId,
    this.assessmentTitle,
    this.itemType = 'practice',
    this.sortOrder = 0,
  });

  final String id;
  final String assessmentId;
  final String? assessmentTitle;
  final String itemType;
  final int sortOrder;

  String get displayTitle {
    final title = assessmentTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return itemTypeLabel;
  }

  String get itemTypeLabel {
    final raw = itemType.trim().toLowerCase();
    if (raw.isEmpty) return 'Practice';
    return raw
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  factory ExamSeriesItem.fromJson(Map<String, dynamic> json) {
    return ExamSeriesItem(
      id: json['id']?.toString() ?? '',
      assessmentId: json['assessment_id']?.toString() ??
          json['assessmentId']?.toString() ??
          '',
      assessmentTitle: json['assessment_title']?.toString() ??
          json['assessmentTitle']?.toString(),
      itemType: (json['item_type'] ?? json['itemType'] ?? 'practice').toString(),
      sortOrder: _int(json['sort_order'] ?? json['sortOrder']) ?? 0,
    );
  }
}

class ExamSeriesPack {
  const ExamSeriesPack({
    required this.id,
    required this.title,
    this.description,
    this.itemCount = 0,
    this.items = const [],
    this.organizationId,
    this.organizationName,
    this.entitlementSource,
    this.workspaceOrganizationId,
    this.workspaceHint,
  });

  final String id;
  final String title;
  final String? description;
  final int itemCount;
  final List<ExamSeriesItem> items;
  final String? organizationId;
  final String? organizationName;
  final String? entitlementSource;
  final String? workspaceOrganizationId;
  final String? workspaceHint;

  String get sellerOrganizationId =>
      (workspaceOrganizationId ?? organizationId ?? '').trim();

  String get fromLabel =>
      (organizationName?.trim().isNotEmpty == true)
          ? organizationName!.trim()
          : 'Your academy';

  int get testsCount => itemCount > 0 ? itemCount : items.length;

  bool needsOrgSwitch(String? activeOrganizationId) {
    final seller = sellerOrganizationId;
    if (seller.isEmpty || activeOrganizationId == null) return false;
    return seller != activeOrganizationId;
  }

  factory ExamSeriesPack.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final items = <ExamSeriesItem>[];
    if (itemsRaw is List) {
      for (final row in itemsRaw) {
        if (row is! Map) continue;
        final item = ExamSeriesItem.fromJson(
          row.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (item.id.isNotEmpty || item.assessmentId.isNotEmpty) {
          items.add(item);
        }
      }
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final workspace = _asMap(json['workspace']);
    final itemCount = _int(json['item_count'] ?? json['itemCount']) ??
        items.length;

    return ExamSeriesPack(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? 'Exam series').toString(),
      description: json['description']?.toString(),
      itemCount: itemCount,
      items: items,
      organizationId: json['organization_id']?.toString() ??
          json['organizationId']?.toString(),
      organizationName: json['organization_name']?.toString() ??
          json['organizationName']?.toString(),
      entitlementSource: json['entitlement_source']?.toString() ??
          json['entitlementSource']?.toString(),
      workspaceOrganizationId: workspace['organization_id']?.toString() ??
          workspace['organizationId']?.toString(),
      workspaceHint: workspace['hint']?.toString(),
    );
  }
}

class ExamSeriesRank {
  const ExamSeriesRank({
    this.disclosed = false,
    this.rank,
    this.totalMarks,
    this.cohortSize = 0,
    this.assessmentsScored = 0,
    this.assessmentsInSeries = 0,
    this.assessmentsDisclosed,
    this.message,
  });

  final bool disclosed;
  final int? rank;
  final double? totalMarks;
  final int cohortSize;
  final int assessmentsScored;
  final int assessmentsInSeries;
  final int? assessmentsDisclosed;
  final String? message;

  bool get hasRank => disclosed && rank != null;

  String get disclosureBlurb {
    final disclosedCount = assessmentsDisclosed ?? assessmentsInSeries;
    return 'Based on $assessmentsScored/$disclosedCount disclosed assessments '
        'in this pack. Ranks appear after your academy discloses marks.';
  }

  factory ExamSeriesRank.fromJson(Map<String, dynamic> json) {
    return ExamSeriesRank(
      disclosed: json['disclosed'] == true,
      rank: _int(json['rank']),
      totalMarks: _num(json['total_marks'] ?? json['totalMarks']),
      cohortSize: _int(json['cohort_size'] ?? json['cohortSize']) ?? 0,
      assessmentsScored:
          _int(json['assessments_scored'] ?? json['assessmentsScored']) ?? 0,
      assessmentsInSeries:
          _int(json['assessments_in_series'] ?? json['assessmentsInSeries']) ??
              0,
      assessmentsDisclosed:
          _int(json['assessments_disclosed'] ?? json['assessmentsDisclosed']),
      message: json['message']?.toString(),
    );
  }
}

class ExamSeriesHubSnapshot {
  const ExamSeriesHubSnapshot({
    this.packs = const [],
    this.activeOrganizationId,
  });

  final List<ExamSeriesPack> packs;
  final String? activeOrganizationId;

  bool get isEmpty => packs.isEmpty;
}

class ExamSeriesDetailSnapshot {
  const ExamSeriesDetailSnapshot({
    required this.pack,
    this.rank,
    this.rankUnavailable = false,
  });

  final ExamSeriesPack pack;
  final ExamSeriesRank? rank;
  final bool rankUnavailable;
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

int? _int(Object? raw) {
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

double? _num(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}
