import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local mentor feedback prefs — mirrors student-web `useMentorPrefs`.
class MentorPrefs {
  const MentorPrefs({
    this.liked = const {},
    this.disliked = const {},
    this.dislikeReasons = const {},
  });

  final Set<String> liked;
  final Set<String> disliked;
  final Map<String, String> dislikeReasons;

  MentorPrefs copyWith({
    Set<String>? liked,
    Set<String>? disliked,
    Map<String, String>? dislikeReasons,
  }) {
    return MentorPrefs(
      liked: liked ?? this.liked,
      disliked: disliked ?? this.disliked,
      dislikeReasons: dislikeReasons ?? this.dislikeReasons,
    );
  }
}

class MentorPrefsStore {
  MentorPrefsStore({SharedPreferences? preferences}) : _prefs = preferences;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _store() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static String keyFor(String studentProfileId) =>
      'pragyu.mentor.prefs.v1:$studentProfileId';

  Future<MentorPrefs> load(String studentProfileId) async {
    if (studentProfileId.isEmpty) return const MentorPrefs();
    try {
      final raw = (await _store()).getString(keyFor(studentProfileId));
      if (raw == null || raw.isEmpty) return const MentorPrefs();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const MentorPrefs();
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      final liked = _stringSet(map['liked']);
      final disliked = _stringSet(map['disliked']);
      final reasonsRaw = map['dislikeReasons'];
      final reasons = <String, String>{};
      if (reasonsRaw is Map) {
        for (final entry in reasonsRaw.entries) {
          final value = entry.value?.toString().trim() ?? '';
          if (value.isEmpty) continue;
          reasons[entry.key.toString()] = value;
        }
      }
      return MentorPrefs(
        liked: liked,
        disliked: disliked,
        dislikeReasons: reasons,
      );
    } catch (_) {
      return const MentorPrefs();
    }
  }

  Future<void> save(String studentProfileId, MentorPrefs prefs) async {
    if (studentProfileId.isEmpty) return;
    final payload = jsonEncode({
      'liked': prefs.liked.toList(growable: false),
      'disliked': prefs.disliked.toList(growable: false),
      'dislikeReasons': prefs.dislikeReasons,
    });
    await (await _store()).setString(keyFor(studentProfileId), payload);
  }

  Future<MentorPrefs> toggleLike({
    required String studentProfileId,
    required MentorPrefs current,
    required String messageId,
  }) async {
    final liked = {...current.liked};
    final disliked = {...current.disliked};
    final reasons = {...current.dislikeReasons};
    if (liked.contains(messageId)) {
      liked.remove(messageId);
    } else {
      liked.add(messageId);
      disliked.remove(messageId);
      reasons.remove(messageId);
    }
    final next = current.copyWith(
      liked: liked,
      disliked: disliked,
      dislikeReasons: reasons,
    );
    await save(studentProfileId, next);
    return next;
  }

  Future<MentorPrefs> setDislike({
    required String studentProfileId,
    required MentorPrefs current,
    required String messageId,
    String? reason,
  }) async {
    final liked = {...current.liked};
    final disliked = {...current.disliked};
    final reasons = {...current.dislikeReasons};
    final sameReason = reason != null && reasons[messageId] == reason;
    if (disliked.contains(messageId) && (reason == null || sameReason)) {
      disliked.remove(messageId);
      reasons.remove(messageId);
    } else {
      disliked.add(messageId);
      liked.remove(messageId);
      if (reason != null && reason.isNotEmpty) {
        reasons[messageId] = reason;
      } else {
        reasons.remove(messageId);
      }
    }
    final next = current.copyWith(
      liked: liked,
      disliked: disliked,
      dislikeReasons: reasons,
    );
    await save(studentProfileId, next);
    return next;
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is! List) return {};
    return {
      for (final item in raw)
        if (item != null && item.toString().isNotEmpty) item.toString(),
    };
  }
}
