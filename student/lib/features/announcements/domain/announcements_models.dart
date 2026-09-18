/// S-69 Announcements — institute/course notices for the signed-in student.
class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    this.announcementType,
    this.isPinned = false,
    this.publishedAt,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String body;
  final String? announcementType;
  final bool isPinned;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  String get plainBody => stripAnnouncementHtml(body);

  String get typeLabel {
    final raw = (announcementType ?? '').trim();
    if (raw.isEmpty) return 'Notice';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: json['id']?.toString() ?? '',
      title: (json['title']?.toString() ?? '').trim().isEmpty
          ? 'Announcement'
          : json['title'].toString().trim(),
      body: json['body']?.toString() ?? '',
      announcementType: _nullableTrim(json['announcement_type']?.toString()),
      isPinned: json['is_pinned'] == true,
      publishedAt: _parseDate(
        json['published_at']?.toString() ?? json['created_at']?.toString(),
      ),
      expiresAt: _parseDate(json['expires_at']?.toString()),
    );
  }
}

class AnnouncementsSnapshot {
  const AnnouncementsSnapshot({this.items = const []});

  final List<AnnouncementItem> items;

  List<AnnouncementItem> get pinned =>
      items.where((item) => item.isPinned).toList(growable: false);

  List<AnnouncementItem> get unpinned =>
      items.where((item) => !item.isPinned).toList(growable: false);
}

/// Route args for announcement detail.
class AnnouncementDetailArgs {
  const AnnouncementDetailArgs({
    this.announcementId,
    this.item,
  });

  final String? announcementId;
  final AnnouncementItem? item;

  String? get resolvedId =>
      item?.id.trim().isNotEmpty == true
          ? item!.id
          : announcementId?.trim();

  static AnnouncementDetailArgs fromObject(Object? value) {
    if (value is AnnouncementDetailArgs) return value;
    if (value is AnnouncementItem) {
      return AnnouncementDetailArgs(item: value, announcementId: value.id);
    }
    if (value is String && value.trim().isNotEmpty) {
      return AnnouncementDetailArgs(announcementId: value.trim());
    }
    if (value is Map) {
      final map = value.map((k, v) => MapEntry(k.toString(), v));
      final itemRaw = map['item'];
      AnnouncementItem? item;
      if (itemRaw is AnnouncementItem) {
        item = itemRaw;
      } else if (itemRaw is Map) {
        item = AnnouncementItem.fromJson(
          itemRaw.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return AnnouncementDetailArgs(
        announcementId: map['announcementId']?.toString() ??
            map['announcement_id']?.toString() ??
            map['id']?.toString(),
        item: item,
      );
    }
    return const AnnouncementDetailArgs();
  }
}

String stripAnnouncementHtml(String html) {
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  return text.trim();
}

String? _nullableTrim(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
