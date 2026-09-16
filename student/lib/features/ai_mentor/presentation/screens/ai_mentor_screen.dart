import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/ai_mentor/data/ai_mentor_repository.dart';
import 'package:student_mobile/features/ai_mentor/domain/ai_mentor_models.dart';

/// S-60 AI Mentor — coach chat for doubts and study guidance.
class AiMentorScreen extends StatefulWidget {
  const AiMentorScreen({
    super.key,
    this.mentorRepository,
  });

  final AiMentorGateway? mentorRepository;

  @override
  State<AiMentorScreen> createState() => _AiMentorScreenState();
}

class _AiMentorScreenState extends State<AiMentorScreen> {
  late final AiMentorGateway _mentor =
      widget.mentorRepository ?? AiMentorRepository();

  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  MentorChatSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _mentor.loadChat();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to open AI Mentor.';
      });
    }
  }

  Future<void> _startNewChat() async {
    final current = _snapshot;
    if (current == null) return;
    setState(() {
      _snapshot = MentorChatSnapshot(
        studentProfileId: current.studentProfileId,
        sessions: current.sessions,
        weakTopics: current.weakTopics,
        recommendationTitles: current.recommendationTitles,
      );
      _error = null;
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _composer.text).trim();
    if (text.isEmpty || _sending) return;

    final snapshot = _snapshot;
    if (snapshot == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    if (preset == null) {
      _composer.clear();
    }

    // Optimistic user bubble while waiting.
    final optimistic = MentorMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      role: MentorMessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    final priorMessages = snapshot.messages;
    setState(() {
      _snapshot = snapshot.copyWith(
        session: MentorSession(
          id: snapshot.session?.id ?? '',
          studentProfileId: snapshot.studentProfileId,
          status: snapshot.session?.status ?? 'active',
          createdAt: snapshot.session?.createdAt,
          messages: [...priorMessages, optimistic],
          context: snapshot.session?.context ?? const {},
        ),
      );
    });
    _scrollToBottom();

    try {
      var session = snapshot.session;
      if (session == null || session.id.isEmpty) {
        session = await _mentor.startSession(
          studentProfileId: snapshot.studentProfileId,
          context: buildMentorContext(
            weakTopics: snapshot.weakTopics,
            recommendationTitles: snapshot.recommendationTitles,
          ),
        );
      }

      final updated = await _mentor.sendMessage(
        sessionId: session.id,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _snapshot = snapshot.copyWith(
          session: updated,
          sessions: [
            updated,
            ...snapshot.sessions.where((item) => item.id != updated.id),
          ],
        );
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _snapshot = snapshot;
        _error = error is ApiException
            ? error.message
            : 'Unable to send message.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('AI Mentor'),
          actions: [
            IconButton(
              tooltip: 'New chat',
              onPressed: _snapshot == null || _sending ? null : _startNewChat,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: _loading && _snapshot == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && _snapshot == null
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : Column(
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                height: 1.35,
                              ),
                            ),
                          ),
                        Expanded(child: _buildMessages()),
                        _Composer(
                          controller: _composer,
                          sending: _sending,
                          enabled: _snapshot != null,
                          onSend: _send,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final snapshot = _snapshot;
    final messages = snapshot?.messages ?? const <MentorMessage>[];

    if (messages.isEmpty) {
      return ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        children: [
          const _EmptyHero(),
          if (snapshot != null && snapshot.weakTopics.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Ask about a weak topic',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in snapshot.weakTopics.take(4))
                  ActionChip(
                    label: Text(topic),
                    onPressed: _sending
                        ? null
                        : () => _send('Help me improve on: $topic'),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.brandSoft),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (_sending && index == messages.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TypingBubble(),
            ),
          );
        }
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MessageBubble(
            message: message,
            onFollowUp: _sending ? null : _send,
          ),
        );
      },
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome, size: 36, color: AppColors.brand),
          SizedBox(height: 14),
          Text(
            'Ask your AI Mentor',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Get help with doubts, weak topics, and how to improve your next answers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onFollowUp,
  });

  final MentorMessage message;
  final ValueChanged<String>? onFollowUp;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.brand : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.brandSoft),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.ink,
                  height: 1.45,
                ),
              ),
            ),
            if (!isUser && message.followUpQuestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final question in message.followUpQuestions.take(3))
                    ActionChip(
                      label: Text(
                        question,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed:
                          onFollowUp == null ? null : () => onFollowUp!(question),
                      backgroundColor: AppColors.brandSoft,
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.brand,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Mentor is thinking…',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled && !sending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask a doubt…',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.brandSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.brandSoft),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled && !sending ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.brandSoft,
              ),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
