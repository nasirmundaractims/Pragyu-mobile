/// S-60 AI Mentor / Coach models.

enum MentorMessageRole { user, assistant, system, tool, unknown }

class MentorMessage {
  const MentorMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
    this.followUpQuestions = const [],
    this.referencedTopics = const [],
  });

  final String id;
  final MentorMessageRole role;
  final String content;
  final DateTime? createdAt;
  final List<String> followUpQuestions;
  final List<String> referencedTopics;

  bool get isUser => role == MentorMessageRole.user;
  bool get isAssistant => role == MentorMessageRole.assistant;

  factory MentorMessage.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final metadata = _asMap(json['metadata_json'] ?? json['metadata']);
    return MentorMessage(
      id: json['id']?.toString() ?? 'msg-$index',
      role: parseMentorRole(json['role']?.toString()),
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']?.toString()),
      followUpQuestions: _stringList(metadata['follow_up_questions']),
      referencedTopics: _stringList(metadata['referenced_topics']),
    );
  }
}

class MentorSession {
  const MentorSession({
    required this.id,
    required this.studentProfileId,
    this.status = 'active',
    this.createdAt,
    this.messages = const [],
    this.context = const {},
  });

  final String id;
  final String studentProfileId;
  final String status;
  final DateTime? createdAt;
  final List<MentorMessage> messages;
  final Map<String, dynamic> context;

  bool get isActive => status.toLowerCase() == 'active';

  factory MentorSession.fromJson(Map<String, dynamic> json) {
    final messagesRaw = json['messages'];
    final messages = <MentorMessage>[];
    if (messagesRaw is List) {
      for (var i = 0; i < messagesRaw.length; i++) {
        final row = messagesRaw[i];
        if (row is Map) {
          messages.add(
            MentorMessage.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
              index: i,
            ),
          );
        }
      }
    }

    return MentorSession(
      id: json['id']?.toString() ?? '',
      studentProfileId: json['student_profile_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdAt: _parseDate(json['created_at']?.toString()),
      messages: messages,
      context: _asMap(json['context_json'] ?? json['context']),
    );
  }
}

class MentorChatSnapshot {
  const MentorChatSnapshot({
    required this.studentProfileId,
    this.session,
    this.sessions = const [],
    this.weakTopics = const [],
    this.recommendationTitles = const [],
  });

  final String studentProfileId;
  final MentorSession? session;
  final List<MentorSession> sessions;
  final List<String> weakTopics;
  final List<String> recommendationTitles;

  List<MentorMessage> get messages => session?.messages ?? const [];

  MentorChatSnapshot copyWith({
    MentorSession? session,
    List<MentorSession>? sessions,
  }) {
    return MentorChatSnapshot(
      studentProfileId: studentProfileId,
      session: session ?? this.session,
      sessions: sessions ?? this.sessions,
      weakTopics: weakTopics,
      recommendationTitles: recommendationTitles,
    );
  }
}

MentorMessageRole parseMentorRole(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case 'user':
      return MentorMessageRole.user;
    case 'assistant':
      return MentorMessageRole.assistant;
    case 'system':
      return MentorMessageRole.system;
    case 'tool':
      return MentorMessageRole.tool;
    default:
      return MentorMessageRole.unknown;
  }
}

Map<String, dynamic> buildMentorContext({
  List<String> weakTopics = const [],
  List<String> recommendationTitles = const [],
  String? studentDisplayName,
}) {
  return {
    'source': 'student-mobile-ai-mentor',
    if (studentDisplayName != null && studentDisplayName.trim().isNotEmpty)
      'student_display_name': studentDisplayName.trim(),
    'weak_topics': weakTopics.take(8).toList(growable: false),
    'recommendation_titles':
        recommendationTitles.take(5).toList(growable: false),
    'instructions':
        "You are the student's AI Mentor. Use known weak topics and recommendations when helpful. Respond with clear next actions.",
  };
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
