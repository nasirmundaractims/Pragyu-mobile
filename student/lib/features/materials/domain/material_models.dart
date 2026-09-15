/// Route args for S-27 Study materials list.
class StudyMaterialsListArgs {
  const StudyMaterialsListArgs({
    this.courseId,
    this.courseTitle,
  });

  final String? courseId;
  final String? courseTitle;

  factory StudyMaterialsListArgs.fromObject(Object? raw) {
    if (raw is StudyMaterialsListArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return StudyMaterialsListArgs(
        courseId:
            map['courseId']?.toString() ?? map['course_id']?.toString(),
        courseTitle:
            map['courseTitle']?.toString() ?? map['course_title']?.toString(),
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return StudyMaterialsListArgs(courseId: raw);
    }
    return const StudyMaterialsListArgs();
  }
}

enum StudyMaterialKind { pdf, notes, presentation, other }

enum MaterialAccessState { playable, free, locked, unknown }

class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.title,
    this.materialType = StudyMaterialKind.other,
    this.accessState = MaterialAccessState.unknown,
    this.isFree = false,
    this.mediaFileId,
    this.externalUrl,
    this.courseId,
    this.courseTitle,
  });

  final String id;
  final String title;
  final StudyMaterialKind materialType;
  final MaterialAccessState accessState;
  final bool isFree;
  final String? mediaFileId;
  final String? externalUrl;
  final String? courseId;
  final String? courseTitle;

  bool get isLocked => accessState == MaterialAccessState.locked;

  bool get canOpen =>
      accessState == MaterialAccessState.playable ||
      accessState == MaterialAccessState.free;

  String get typeLabel {
    switch (materialType) {
      case StudyMaterialKind.pdf:
        return 'PDF';
      case StudyMaterialKind.notes:
        return 'Notes';
      case StudyMaterialKind.presentation:
        return 'Presentation';
      case StudyMaterialKind.other:
        return 'Material';
    }
  }

  String get accessLabel {
    switch (accessState) {
      case MaterialAccessState.playable:
        return 'Available';
      case MaterialAccessState.free:
        return 'Free preview';
      case MaterialAccessState.locked:
        return 'Locked';
      case MaterialAccessState.unknown:
        return isFree ? 'Free' : 'Available';
    }
  }

  String get subtitle {
    final parts = <String>[
      typeLabel,
      if (courseTitle != null && courseTitle!.isNotEmpty) courseTitle!,
      accessLabel,
    ];
    return parts.join(' · ');
  }

  /// Opens S-28 Material viewer when that screen ships.
  String get nextScreenId => 'S-28';

  factory StudyMaterial.fromJson(
    Map<String, dynamic> json, {
    String? courseId,
    String? courseTitle,
  }) {
    return StudyMaterial(
      id: json['id']?.toString() ?? '',
      title: (json['title']?.toString() ?? '').trim().isEmpty
          ? 'Untitled material'
          : json['title'].toString().trim(),
      materialType: _parseType(json['material_type']?.toString()),
      accessState: _parseAccess(json['access_state']?.toString()),
      isFree: json['is_free'] == true,
      mediaFileId: json['media_file_id']?.toString(),
      externalUrl: json['external_url']?.toString(),
      courseId: courseId ??
          json['course_id']?.toString() ??
          json['courseId']?.toString(),
      courseTitle: courseTitle ??
          json['course_title']?.toString() ??
          json['courseTitle']?.toString(),
    );
  }

  static StudyMaterialKind _parseType(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'pdf':
        return StudyMaterialKind.pdf;
      case 'notes':
        return StudyMaterialKind.notes;
      case 'presentation':
        return StudyMaterialKind.presentation;
      default:
        return StudyMaterialKind.other;
    }
  }

  static MaterialAccessState _parseAccess(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'playable':
        return MaterialAccessState.playable;
      case 'free':
        return MaterialAccessState.free;
      case 'locked':
        return MaterialAccessState.locked;
      default:
        return MaterialAccessState.unknown;
    }
  }
}

class StudyMaterialsSnapshot {
  const StudyMaterialsSnapshot({this.items = const []});

  final List<StudyMaterial> items;

  bool get isEmpty => items.isEmpty;
}
