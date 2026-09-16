import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/lectures/presentation/widgets/livekit_stage.dart';

/// S-25 Live class room — LiveKit media, chat, heartbeat, leave.
class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({
    super.key,
    required this.args,
    this.lecturesRepository,
    this.chatPollInterval = const Duration(seconds: 5),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  final LiveRoomArgs args;
  final LecturesGateway? lecturesRepository;

  /// Set to `null` / zero to disable timers (tests).
  final Duration? chatPollInterval;
  final Duration? heartbeatInterval;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  late final LecturesGateway _lectures =
      widget.lecturesRepository ?? LecturesRepository();

  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  bool _loadingChat = true;
  bool _sending = false;
  String? _chatError;
  List<LiveChatMessage> _messages = const [];
  Timer? _chatPoll;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _startTimers();
    _sendHeartbeat();
  }

  @override
  void dispose() {
    _chatPoll?.cancel();
    _heartbeat?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimers() {
    final chatInterval = widget.chatPollInterval;
    if (chatInterval != null && chatInterval > Duration.zero) {
      _chatPoll = Timer.periodic(chatInterval, (_) => _loadChat(silent: true));
    }
    final beatInterval = widget.heartbeatInterval;
    if (beatInterval != null && beatInterval > Duration.zero) {
      _heartbeat = Timer.periodic(beatInterval, (_) => _sendHeartbeat());
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _lectures.sendAttendanceHeartbeat(widget.args.lectureId);
    } catch (_) {
      // Ignore transient failures; next tick retries.
    }
  }

  Future<void> _loadChat({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingChat = true;
        _chatError = null;
      });
    }
    try {
      final messages = await _lectures.listLiveChat(widget.args.lectureId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loadingChat = false;
        _chatError = null;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _loadingChat = false;
        _chatError = 'Unable to load chat.';
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final posted = await _lectures.postLiveChat(widget.args.lectureId, text);
      if (!mounted) return;
      _chatController.clear();
      setState(() {
        _messages = [..._messages, posted];
        _sending = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _leave() {
    _chatPoll?.cancel();
    _heartbeat?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.title?.trim().isNotEmpty == true
        ? widget.args.title!.trim()
        : 'Live class';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Live room'),
          actions: [
            TextButton(
              onPressed: _leave,
              child: const Text('Leave'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: widget.args.hasLiveKitCredentials
                    ? LiveKitStage(
                        url: widget.args.mediaUrl!,
                        token: widget.args.livekitToken!,
                        canPublish: widget.args.canPublish,
                      )
                    : _MediaFallback(mediaUrl: widget.args.mediaUrl),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Class chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildChat()),
              _ChatComposer(
                controller: _chatController,
                sending: _sending,
                onSend: _sendChat,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChat() {
    if (_loadingChat && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    if (_chatError != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _chatError!,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Say hello to the class.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ChatBubble(message: message),
        );
      },
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({this.mediaUrl});

  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2433),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_outlined,
            color: Colors.white70,
            size: 36,
          ),
          const SizedBox(height: 10),
          const Text(
            'Live now',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mediaUrl != null && mediaUrl!.isNotEmpty
                ? 'Waiting for media credentials…'
                : 'Join again when the class goes live.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final LiveChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.authorLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: message.isFaculty ? AppColors.accent : AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message the class',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.brandSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.brandSoft),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
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
