import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/ai_mentor/data/ai_mentor_repository.dart';
import 'package:student_mobile/features/ai_mentor/domain/ai_mentor_models.dart';
import 'package:student_mobile/features/ai_mentor/presentation/screens/ai_mentor_screen.dart';

class _FakeMentor implements AiMentorGateway {
  _FakeMentor({
    required this.snapshot,
    this.sendResult,
  });

  MentorChatSnapshot snapshot;
  MentorSession? sendResult;
  String? lastSentContent;
  int startCalls = 0;
  int sendCalls = 0;

  @override
  Future<MentorChatSnapshot> loadChat() async => snapshot;

  @override
  Future<MentorSession> startSession({
    required String studentProfileId,
    Map<String, dynamic>? context,
  }) async {
    startCalls += 1;
    final created = MentorSession(
      id: 'sess-new',
      studentProfileId: studentProfileId,
      status: 'active',
      createdAt: DateTime(2026, 9, 16),
      context: context ?? const {},
    );
    snapshot = snapshot.copyWith(session: created, sessions: [created]);
    return created;
  }

  @override
  Future<MentorSession> getSession(String sessionId) async {
    return snapshot.session ??
        MentorSession(id: sessionId, studentProfileId: snapshot.studentProfileId);
  }

  @override
  Future<MentorSession> sendMessage({
    required String sessionId,
    required String content,
    Map<String, dynamic>? context,
  }) async {
    sendCalls += 1;
    lastSentContent = content;
    if (sendResult != null) {
      snapshot = snapshot.copyWith(session: sendResult);
      return sendResult!;
    }
    final updated = MentorSession(
      id: sessionId,
      studentProfileId: snapshot.studentProfileId,
      status: 'active',
      messages: [
        ...snapshot.messages.where((m) => !m.id.startsWith('local-')),
        MentorMessage(
          id: 'u-$sendCalls',
          role: MentorMessageRole.user,
          content: content,
        ),
        MentorMessage(
          id: 'a-$sendCalls',
          role: MentorMessageRole.assistant,
          content: 'Here is a tip for: $content',
          followUpQuestions: const ['Want a practice question?'],
        ),
      ],
    );
    snapshot = snapshot.copyWith(session: updated);
    return updated;
  }
}

void main() {
  testWidgets('S-60 empty chat shows hero and weak-topic chip', (tester) async {
    final fake = _FakeMentor(
      snapshot: const MentorChatSnapshot(
        studentProfileId: 'sp-1',
        weakTopics: ['Federalism'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AiMentorScreen(mentorRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ask your AI Mentor'), findsOneWidget);
    expect(find.text('Federalism'), findsOneWidget);

    await tester.tap(find.text('Federalism'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(fake.startCalls, 1);
    expect(fake.sendCalls, 1);
    expect(fake.lastSentContent, 'Help me improve on: Federalism');
    expect(find.textContaining('Here is a tip'), findsOneWidget);
  });

  testWidgets('S-60 sends composer message in existing session', (tester) async {
    final fake = _FakeMentor(
      snapshot: MentorChatSnapshot(
        studentProfileId: 'sp-1',
        session: MentorSession(
          id: 'sess-1',
          studentProfileId: 'sp-1',
          messages: const [
            MentorMessage(
              id: 'm1',
              role: MentorMessageRole.assistant,
              content: 'Welcome back.',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AiMentorScreen(mentorRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Explain DPSP');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(fake.startCalls, 0);
    expect(fake.sendCalls, 1);
    expect(fake.lastSentContent, 'Explain DPSP');
    expect(find.text('Want a practice question?'), findsOneWidget);
  });
}
