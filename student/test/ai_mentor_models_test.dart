import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/ai_mentor/domain/ai_mentor_models.dart';

void main() {
  test('MentorSession.fromJson parses messages and metadata', () {
    final session = MentorSession.fromJson({
      'id': 'sess-1',
      'student_profile_id': 'sp-1',
      'status': 'active',
      'created_at': '2026-09-16T10:00:00Z',
      'context_json': {'weak_topics': ['Federalism']},
      'messages': [
        {
          'id': 'm1',
          'role': 'user',
          'content': 'Help with federalism',
          'created_at': '2026-09-16T10:01:00Z',
        },
        {
          'id': 'm2',
          'role': 'assistant',
          'content': 'Start with the Seventh Schedule.',
          'metadata': {
            'follow_up_questions': ['What is concurrent list?'],
            'referenced_topics': ['Federalism'],
          },
        },
      ],
    });

    expect(session.id, 'sess-1');
    expect(session.isActive, isTrue);
    expect(session.messages, hasLength(2));
    expect(session.messages.first.isUser, isTrue);
    expect(session.messages.last.isAssistant, isTrue);
    expect(
      session.messages.last.followUpQuestions,
      ['What is concurrent list?'],
    );
  });

  test('buildMentorContext includes weak topics and recommendations', () {
    final context = buildMentorContext(
      weakTopics: ['Polity', 'Economy', 'History'],
      recommendationTitles: ['Revise FR', 'Practice GS'],
      studentDisplayName: 'Alex',
    );

    expect(context['source'], 'student-mobile-ai-mentor');
    expect(context['student_display_name'], 'Alex');
    expect(context['weak_topics'], ['Polity', 'Economy', 'History']);
    expect(context['recommendation_titles'], ['Revise FR', 'Practice GS']);
    expect(context['instructions'], contains('AI Mentor'));
  });
}
