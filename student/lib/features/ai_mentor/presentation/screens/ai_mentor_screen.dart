import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/ai_mentor/data/ai_mentor_repository.dart';
import 'package:student_mobile/features/ai_mentor/domain/ai_mentor_models.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';

/// Enables mouse / trackpad drag for horizontal strips (needed on Flutter web).
class _MentorDragScrollBehavior extends MaterialScrollBehavior {
  const _MentorDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Horizontal scroller that also maps mouse-wheel to sideways scroll on web.
class _HScrollStrip extends StatefulWidget {
  const _HScrollStrip({
    required this.height,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final double height;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  State<_HScrollStrip> createState() => _HScrollStripState();
}

class _HScrollStripState extends State<_HScrollStrip> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    // Claim the wheel event so the parent vertical list does not steal it.
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is! PointerScrollEvent || !_controller.hasClients) return;
      final position = _controller.position;
      final delta = resolved.scrollDelta.dy != 0
          ? resolved.scrollDelta.dy
          : resolved.scrollDelta.dx;
      final next = (_controller.offset + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (next != _controller.offset) {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: const _MentorDragScrollBehavior(),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: widget.padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  widget.children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// S-60 AI Mentor — coach chat for doubts and study guidance.
class AiMentorScreen extends StatefulWidget {
  const AiMentorScreen({
    super.key,
    this.mentorRepository,
    this.sessionService,
  });

  final AiMentorGateway? mentorRepository;
  final SessionService? sessionService;

  @override
  State<AiMentorScreen> createState() => _AiMentorScreenState();
}

class _AiMentorScreenState extends State<AiMentorScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _pageBg = Color(0xFFF8FAFD);
  static const _softBlue = Color(0xFFE8F3FF);
  static const _pillBg = Color(0xFFF0E9FF);
  static const _heroAsset = 'assets/images/onboarding/hero_companion.png';

  late final AiMentorGateway _mentor =
      widget.mentorRepository ?? AiMentorRepository();
  late final SessionService _session =
      widget.sessionService ?? SessionService();

  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _composerFocus = FocusNode();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  MentorChatSnapshot? _snapshot;
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUser();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final session = await _session.read();
      if (!mounted) return;
      setState(() => _user = session?.cachedUser);
    } catch (_) {}
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

  Future<void> _openSession(MentorSession listed) async {
    if (_sending) return;
    Navigator.of(context).maybePop();
    setState(() => _sending = true);
    try {
      final full = await _mentor.getSession(listed.id);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _snapshot = _snapshot?.copyWith(
          session: full,
          sessions: [
            full,
            ...(_snapshot?.sessions ?? const <MentorSession>[])
                .where((item) => item.id != full.id),
          ],
        );
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to open that chat.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  String get _firstName {
    final name = _user?.firstName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final display = _user?.displayName.trim();
    if (display != null && display.isNotEmpty) {
      return display.split(RegExp(r'\s+')).first;
    }
    return 'there';
  }

  String get _initials {
    final display = _user?.displayName.trim();
    if (display == null || display.isEmpty) return 'You';
    final parts = display.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'You' : letters;
  }

  Future<void> _showHistory() async {
    final sessions = _snapshot?.sessions ?? const <MentorSession>[];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chat history',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No previous chats yet. Ask a question to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.4),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sessions.length.clamp(0, 12),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final preview = session.messages.isNotEmpty
                            ? session.messages.last.content
                            : 'Session ${session.id}';
                        final active = _snapshot?.session?.id == session.id;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: active ? _blue : _muted,
                          ),
                          title: Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: _ink,
                            ),
                          ),
                          subtitle: session.createdAt == null
                              ? null
                              : Text(
                                  _formatTime(session.createdAt!),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                          onTap: () => _openSession(session),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _startNewChat();
                  },
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Start new chat'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onQuickAction(_QuickAction action) {
    switch (action.id) {
      case 'more':
        Navigator.of(context).pushNamed(AppRoutes.weakTopics);
        return;
      case 'plan':
        Navigator.of(context).pushNamed(AppRoutes.studyPlanner);
        return;
      case 'evaluate':
        Navigator.of(context).pushNamed(AppRoutes.pastResults);
        return;
      default:
        final prompt = action.prompt;
        if (prompt == null || prompt.isEmpty) {
          _composerFocus.requestFocus();
          return;
        }
        if (prompt.trimRight().endsWith(':')) {
          _composer.text = prompt;
          _composer.selection = TextSelection.collapsed(
            offset: _composer.text.length,
          );
          _composerFocus.requestFocus();
          return;
        }
        _send(prompt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: Column(
            children: [
              _MentorHeader(
                onBack: () => Navigator.of(context).maybePop(),
                onHistory: _snapshot == null ? null : _showHistory,
                onNewChat:
                    _snapshot == null || _sending ? null : _startNewChat,
                onWeakTopics: () =>
                    Navigator.of(context).pushNamed(AppRoutes.weakTopics),
              ),
              Expanded(
                child: _loading && _snapshot == null
                    ? const Center(
                        child: CircularProgressIndicator(color: _blue),
                      )
                    : _error != null && _snapshot == null
                        ? _ErrorBody(message: _error!, onRetry: _load)
                        : Column(
                            children: [
                              if (_error != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFC0392B),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 4, 0, 8),
                                child: _QuickActionsRow(
                                  actions: _quickActions,
                                  onTap: _sending ? null : _onQuickAction,
                                ),
                              ),
                              Expanded(child: _buildBody()),
                              _Composer(
                                controller: _composer,
                                focusNode: _composerFocus,
                                sending: _sending,
                                enabled: _snapshot != null,
                                onSend: () => _send(),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final snapshot = _snapshot;
    final messages = snapshot?.messages ?? const <MentorMessage>[];
    final empty = messages.isEmpty;

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (empty) ...[
          _WelcomeBanner(
            firstName: _firstName,
            heroAsset: _heroAsset,
          ),
          const SizedBox(height: 8),
        ],
        if (empty &&
            snapshot != null &&
            snapshot.weakTopics.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ask about a weak topic',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.weakTopics),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE6EAF2)),
                ),
            ],
          ),
        ],
        if (!empty) ...[
          const SizedBox(height: 16),
          for (var i = 0; i < messages.length; i++) ...[
            _MessageBubble(
              message: messages[i],
              initials: _initials,
              isLastAssistant: messages[i].isAssistant &&
                  (i == messages.length - 1 ||
                      !messages
                          .skip(i + 1)
                          .any((m) => m.isAssistant)),
              recommendations: snapshot?.recommendationTitles ?? const [],
              onFollowUp: _sending ? null : _send,
              onRecommendation: (title) =>
                  _send('Tell me more about: $title'),
            ),
            const SizedBox(height: 12),
          ],
          if (_sending) ...[
            const _TypingBubble(),
            const SizedBox(height: 8),
          ],
        ] else if (_sending) ...[
          const SizedBox(height: 16),
          const _TypingBubble(),
        ],
      ],
    );
  }

  static const _quickActions = <_QuickAction>[
    _QuickAction(
      id: 'explain',
      title: 'Explain a Concept',
      subtitle: 'Get simple explanations.',
      icon: Icons.chat_bubble_outline_rounded,
      tint: Color(0xFF7B61FF),
      soft: Color(0xFFF0EBFF),
      prompt: 'Explain this concept in simple language: ',
    ),
    _QuickAction(
      id: 'summarize',
      title: 'Summarize Notes',
      subtitle: 'Quick revision summaries.',
      icon: Icons.description_outlined,
      tint: Color(0xFF22A06B),
      soft: Color(0xFFE8F8F0),
      prompt: 'Summarize my notes into key revision points: ',
    ),
    _QuickAction(
      id: 'plan',
      title: 'Create Study Plan',
      subtitle: 'Personalized schedule.',
      icon: Icons.track_changes_outlined,
      tint: Color(0xFFE85D75),
      soft: Color(0xFFFFEEF1),
    ),
    _QuickAction(
      id: 'doubt',
      title: 'Solve Doubts',
      subtitle: 'Ask any question.',
      icon: Icons.help_outline_rounded,
      tint: Color(0xFFF08A3C),
      soft: Color(0xFFFFF2E8),
      prompt: 'I have a doubt. Can you help me understand: ',
    ),
    _QuickAction(
      id: 'evaluate',
      title: 'Evaluate Answer',
      subtitle: 'Get AI feedback.',
      icon: Icons.edit_note_rounded,
      tint: Color(0xFF2F7BFF),
      soft: Color(0xFFE8F0FF),
    ),
    _QuickAction(
      id: 'more',
      title: 'More',
      subtitle: 'Explore all features.',
      icon: Icons.grid_view_rounded,
      tint: Color(0xFF7A8499),
      soft: Color(0xFFF2F4F8),
    ),
  ];
}

class _QuickAction {
  const _QuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.soft,
    this.prompt,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color soft;
  final String? prompt;
}

class _MentorHeader extends StatelessWidget {
  const _MentorHeader({
    required this.onBack,
    this.onHistory,
    this.onNewChat,
    this.onWeakTopics,
  });

  final VoidCallback onBack;
  final VoidCallback? onHistory;
  final VoidCallback? onNewChat;
  final VoidCallback? onWeakTopics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: _AiMentorScreenState._ink,
                ),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PragyuLogo(height: 30, semanticsLabel: 'Pragyu'),
                    SizedBox(height: 2),
                    Text(
                      'Learn • Practice • Grow',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: _AiMentorScreenState._muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chat history',
                onPressed: onHistory,
                icon: const Icon(
                  Icons.history_rounded,
                  color: _AiMentorScreenState._ink,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: _AiMentorScreenState._ink,
                ),
                onSelected: (value) {
                  if (value == 'new') onNewChat?.call();
                  if (value == 'weak') onWeakTopics?.call();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'new',
                    enabled: onNewChat != null,
                    child: const Text('New chat'),
                  ),
                  const PopupMenuItem(
                    value: 'weak',
                    child: Text('Weak topics'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _AiMentorScreenState._pillBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Color(0xFF7B61FF),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'AI Mentor',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w800,
                            color: _AiMentorScreenState._ink,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: '  |  Your Personal Learning Assistant.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w500,
                            color: _AiMentorScreenState._muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.firstName,
    required this.heroAsset,
  });

  final String firstName;
  final String heroAsset;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 14, 14, narrow ? 12 : 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCEEFF), Color(0xFFEFF6FF), Color(0xFFF7FBFF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask your AI Mentor',
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _AiMentorScreenState._ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: narrow ? 72 : 88,
                  maxHeight: narrow ? 96 : 112,
                ),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.asset(
                    heroAsset,
                    fit: BoxFit.contain,
                    semanticLabel: 'Pragyu study companion',
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.smart_toy_outlined,
                      size: 56,
                      color: _AiMentorScreenState._blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Hi $firstName! 👋 I\'m your AI Mentor. Ask me anything '
                        'about your studies, get explanations, solve doubts, '
                        'plan your preparation, or get personalized guidance.',
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          height: 1.4,
                          color: _AiMentorScreenState._ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Better Questions\nBrighter Future',
                      textAlign: TextAlign.right,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: AppTheme.scriptFontFamily,
                        fontSize: narrow ? 18 : 22,
                        height: 1.15,
                        color: const Color(0xFF1F4B9A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 88,
                        height: 3,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: _AiMentorScreenState._blue,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.actions,
    this.onTap,
  });

  final List<_QuickAction> actions;
  final ValueChanged<_QuickAction>? onTap;

  @override
  Widget build(BuildContext context) {
    return _HScrollStrip(
      height: 118,
      children: [
        for (final action in actions)
          Semantics(
            button: true,
            label: action.title,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap == null ? null : () => onTap!(action),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  width: 132,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6EAF2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: action.soft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(action.icon, color: action.tint, size: 20),
                      ),
                      const Spacer(),
                      Text(
                        action.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: _AiMentorScreenState._ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: _AiMentorScreenState._muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
            softWrap: true,
            style: const TextStyle(color: Color(0xFFC0392B), height: 1.4),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: _AiMentorScreenState._blue,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.initials,
    this.isLastAssistant = false,
    this.recommendations = const [],
    this.onFollowUp,
    this.onRecommendation,
  });

  final MentorMessage message;
  final String initials;
  final bool isLastAssistant;
  final List<String> recommendations;
  final ValueChanged<String>? onFollowUp;
  final ValueChanged<String>? onRecommendation;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeLabel =
        message.createdAt == null ? null : _formatTime(message.createdAt!);

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const _MentorAvatar(),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? _AiMentorScreenState._softBlue
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isUser
                          ? const Color(0xFFC9DEFF)
                          : const Color(0xFFE6EAF2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: _AiMentorScreenState._ink,
                          height: 1.45,
                          fontSize: 14,
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(height: 10),
                        _AssistantActions(content: message.content),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              _UserAvatar(initials: initials),
            ],
          ],
        ),
        if (timeLabel != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 44,
              right: isUser ? 44 : 0,
            ),
            child: Text(
              timeLabel,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: _AiMentorScreenState._muted,
              ),
            ),
          ),
        ],
        if (!isUser && message.followUpQuestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final question in message.followUpQuestions.take(3))
                  ActionChip(
                    label: Text(
                      question,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onFollowUp == null
                        ? null
                        : () => onFollowUp!(question),
                    backgroundColor: _AiMentorScreenState._softBlue,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
        ],
        if (!isUser &&
            isLastAssistant &&
            (recommendations.isNotEmpty ||
                message.referencedTopics.isNotEmpty)) ...[
          const SizedBox(height: 12),
          _YouMayAlsoLike(
            topics: message.referencedTopics.isNotEmpty
                ? message.referencedTopics
                : recommendations,
            onTap: onRecommendation,
            onSeeAll: () =>
                Navigator.of(context).pushNamed(AppRoutes.recommendations),
          ),
        ],
      ],
    );
  }
}

class _AssistantActions extends StatelessWidget {
  const _AssistantActions({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _ActionLink(
          icon: Icons.thumb_up_alt_outlined,
          label: 'Helpful',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thanks for the feedback'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        _ActionLink(
          icon: Icons.thumb_down_alt_outlined,
          label: '',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thanks — we\'ll improve'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        _ActionLink(
          icon: Icons.copy_rounded,
          label: 'Copy',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: content));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        _ActionLink(
          icon: Icons.ios_share_rounded,
          label: 'Share',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: content));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message copied to share'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _AiMentorScreenState._muted),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: _AiMentorScreenState._muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _YouMayAlsoLike extends StatelessWidget {
  const _YouMayAlsoLike({
    required this.topics,
    this.onTap,
    this.onSeeAll,
  });

  final List<String> topics;
  final ValueChanged<String>? onTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final items = topics.take(3).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();

    final cards = <(IconData, Color, Color, String, String)>[
      (
        Icons.article_outlined,
        const Color(0xFF2F7BFF),
        const Color(0xFFE8F0FF),
        'Key Points Summary',
        items.isNotEmpty ? items.first : 'Quick revision',
      ),
      (
        Icons.account_balance_outlined,
        const Color(0xFF7B61FF),
        const Color(0xFFF0EBFF),
        'Related Topics',
        items.length > 1 ? items.skip(1).take(2).join(', ') : items.first,
      ),
      (
        Icons.quiz_outlined,
        const Color(0xFF1AABB8),
        const Color(0xFFE6F8FA),
        'Practice Questions',
        'Test your understanding.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'You may also like',
                softWrap: true,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  color: _AiMentorScreenState._ink,
                ),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: _AiMentorScreenState._blue,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('See All >'),
            ),
          ],
        ),
        _HScrollStrip(
          height: 82,
          padding: EdgeInsets.zero,
          children: [
            for (var index = 0; index < cards.length; index++)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap == null
                      ? null
                      : () => onTap!(items[index.clamp(0, items.length - 1)]),
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    width: 210,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6EAF2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cards[index].$3,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            cards[index].$1,
                            color: cards[index].$2,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cards[index].$4,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: _AiMentorScreenState._ink,
                                ),
                              ),
                              Text(
                                cards[index].$5,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  color: _AiMentorScreenState._muted,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _AiMentorScreenState._muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MentorAvatar extends StatelessWidget {
  const _MentorAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _AiMentorScreenState._softBlue,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC9DEFF)),
      ),
      child: const Icon(
        Icons.smart_toy_outlined,
        size: 18,
        color: _AiMentorScreenState._blue,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.initials,
  });

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 32,
        height: 32,
        color: _AiMentorScreenState._ink,
        alignment: Alignment.center,
        child: Text(
          initials.length > 2 ? initials.substring(0, 2) : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _MentorAvatar(),
        SizedBox(width: 8),
        _TypingDots(),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final t = (_controller.value + index * 0.2) % 1.0;
              final scale = 0.6 + (0.4 * (1 - (t - 0.5).abs() * 2));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _AiMentorScreenState._muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _AiMentorScreenState._pageBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE6EAF2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Attach',
                      onPressed: enabled && !sending
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Attachments coming soon',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(
                        Icons.attach_file_rounded,
                        color: _AiMentorScreenState._muted,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: enabled && !sending,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: _AiMentorScreenState._ink,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask your question here...',
                          hintStyle: TextStyle(
                            color: _AiMentorScreenState._muted,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Voice',
                      onPressed: enabled && !sending
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Voice input coming soon'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(
                        Icons.mic_none_rounded,
                        color: _AiMentorScreenState._muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: enabled && !sending
                  ? _AiMentorScreenState._blue
                  : const Color(0xFFB7C9E8),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled && !sending ? onSend : null,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
