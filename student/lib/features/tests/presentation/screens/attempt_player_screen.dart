import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/presentation/widgets/cbt_question_body.dart';
import 'package:student_mobile/features/tests/presentation/widgets/cbt_question_palette.dart';
import 'package:student_mobile/features/tests/presentation/widgets/submit_confirm_sheet.dart';

/// S-43 Attempt player — questions, navigation, autosave; submit via S-44.
class AttemptPlayerScreen extends StatefulWidget {
  const AttemptPlayerScreen({
    super.key,
    required this.args,
    this.testsRepository,
    this.autosaveDebounce = const Duration(milliseconds: 2500),
  });

  final AttemptPlayerArgs args;
  final TestsGateway? testsRepository;
  final Duration autosaveDebounce;

  @override
  State<AttemptPlayerScreen> createState() => _AttemptPlayerScreenState();
}

class _AttemptPlayerScreenState extends State<AttemptPlayerScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  AttemptPlayerSnapshot? _snapshot;
  Map<String, StudentAnswerValue> _answers = {};
  CbtPlayerState _player = const CbtPlayerState();
  int _index = 0;
  CbtAutosaveState _autosave = CbtAutosaveState.idle;
  Timer? _debounce;
  Timer? _clock;
  Duration _remaining = Duration.zero;
  bool _finalized = false;
  bool _uploadingImages = false;
  int _uploadProgress = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _tests.loadAttemptPlayer(widget.args);
      if (!mounted) return;
      final questions = snapshot.questions;
      var index = 0;
      final currentId = snapshot.player.currentQuestionId;
      if (currentId != null) {
        final found = questions.indexWhere((q) => q.answerKey == currentId);
        if (found >= 0) index = found;
      }
      setState(() {
        _snapshot = snapshot;
        _answers = Map<String, StudentAnswerValue>.from(snapshot.answers);
        _player = snapshot.player;
        _index = index;
        _loading = false;
      });
      _syncClock();
      unawaited(_persist(immediate: true));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Unable to open this attempt. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _syncClock() {
    _clock?.cancel();
    final deadline = _player.deadlineAt;
    if (deadline == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }
    void tick() {
      if (!mounted || _finalized) return;
      final left = deadline.difference(DateTime.now());
      setState(() => _remaining = left.isNegative ? Duration.zero : left);
      if (left <= Duration.zero) {
        _clock?.cancel();
        unawaited(_finalize(reason: 'timer', confirmed: true));
      }
    }

    tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  AssessmentQuestionPreview? get _current {
    final questions = _snapshot?.questions;
    if (questions == null || questions.isEmpty) return null;
    if (_index < 0 || _index >= questions.length) return null;
    return questions[_index];
  }

  void _goTo(int index) {
    final questions = _snapshot?.questions;
    if (questions == null || questions.isEmpty) return;
    if (index < 0 || index >= questions.length) return;
    final question = questions[index];
    final visited = {..._player.visited, question.answerKey};
    setState(() {
      _index = index;
      _player = _player.copyWith(
        currentQuestionId: question.answerKey,
        visited: visited.toList(growable: false),
      );
    });
    _schedulePersist();
  }

  void _selectChoice(AnswerChoice choice) {
    final question = _current;
    if (question == null) return;
    setState(() {
      _answers[question.answerKey] = StudentAnswerValue.choice(
        id: choice.id,
        label: choice.label,
      );
    });
    _schedulePersist();
  }

  void _setText(String text) {
    final question = _current;
    if (question == null) return;
    setState(() {
      final current = _answers[question.answerKey];
      _answers[question.answerKey] = (current ?? const StudentAnswerValue())
          .copyWith(text: text);
    });
    _schedulePersist();
  }

  void _clearAnswer() {
    final question = _current;
    if (question == null) return;
    setState(() {
      _answers.remove(question.answerKey);
    });
    _schedulePersist();
  }

  Future<void> _addImages() async {
    final question = _current;
    final snapshot = _snapshot;
    if (question == null || snapshot == null || _uploadingImages) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    List<XFile> files;
    if (source == ImageSource.gallery) {
      files = await _picker.pickMultiImage(imageQuality: 85);
    } else {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      files = photo == null ? const [] : [photo];
    }
    if (files.isEmpty || !mounted) return;

    final batch = files.take(12).toList(growable: false);
    setState(() {
      _uploadingImages = true;
      _uploadProgress = 0;
    });

    final current = _answers[question.answerKey] ?? const StudentAnswerValue();
    final uploaded = <AnswerImageAttachment>[...current.images];
    final startPage = uploaded.length + 1;

    try {
      for (var i = 0; i < batch.length; i++) {
        final file = batch[i];
        final bytes = await file.readAsBytes();
        final attachment = await _tests.uploadAnswerImage(
          submissionId: snapshot.submissionId,
          bytes: bytes,
          fileName: file.name.isNotEmpty ? file.name : 'answer-${i + 1}.jpg',
          mimeType: file.mimeType ?? 'image/jpeg',
          pageNumber: startPage + i,
        );
        uploaded.add(attachment);
        if (!mounted) return;
        setState(() {
          _uploadProgress = (((i + 1) / batch.length) * 100).round();
        });
      }

      setState(() {
        _answers[question.answerKey] = current.copyWith(images: uploaded);
        _uploadingImages = false;
        _uploadProgress = 0;
      });
      _schedulePersist();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            batch.length == 1
                ? 'Answer image uploaded.'
                : '${batch.length} answer images uploaded.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingImages = false;
        _uploadProgress = 0;
        if (uploaded.isNotEmpty) {
          _answers[question.answerKey] = current.copyWith(images: uploaded);
        }
      });
      if (uploaded.isNotEmpty) _schedulePersist();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to upload answer image.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeImage(String mediaFileId) {
    final question = _current;
    if (question == null) return;
    final current = _answers[question.answerKey];
    if (current == null) return;
    final nextImages = current.images
        .where((image) => image.mediaFileId != mediaFileId)
        .toList(growable: false);
    setState(() {
      if (nextImages.isEmpty &&
          (current.text == null || current.text!.trim().isEmpty)) {
        _answers.remove(question.answerKey);
      } else {
        _answers[question.answerKey] = current.copyWith(images: nextImages);
      }
    });
    _schedulePersist();
  }

  bool get _includesMediaAnswers =>
      _answers.values.any((answer) => answer.images.isNotEmpty);

  void _toggleMark({bool advance = false}) {
    final question = _current;
    if (question == null) return;
    final marked = {..._player.markedForReview};
    if (marked.contains(question.answerKey)) {
      marked.remove(question.answerKey);
    } else {
      marked.add(question.answerKey);
    }
    setState(() {
      _player = _player.copyWith(
        markedForReview: marked.toList(growable: false),
      );
    });
    _schedulePersist();
    if (advance) {
      final questions = _snapshot?.questions ?? const [];
      if (_index < questions.length - 1) {
        _goTo(_index + 1);
      }
    }
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(widget.autosaveDebounce, () {
      unawaited(_persist());
    });
  }

  Future<void> _persist({
    bool immediate = false,
    String? submitReason,
    bool allowAfterFinalize = false,
  }) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    if (_finalized && !allowAfterFinalize) return;
    if (!immediate) {
      setState(() => _autosave = CbtAutosaveState.saving);
    }
    try {
      final metadata = <String, dynamic>{
        'answers': {
          for (final entry in _answers.entries) entry.key: entry.value.toJson(),
        },
        'player': _player.toJson(),
        'media_files': buildMediaFilesMetadata(_answers),
        'submit_reason': ?submitReason,
      };
      await _tests.updateSubmissionMetadata(snapshot.submissionId, metadata);
      if (!mounted) return;
      if (!_finalized) {
        setState(() => _autosave = CbtAutosaveState.saved);
      }
    } catch (_) {
      if (!mounted) return;
      if (!_finalized) {
        setState(() => _autosave = CbtAutosaveState.error);
      }
      rethrow;
    }
  }

  Future<void> _requestSubmit() async {
    final snapshot = _snapshot;
    if (snapshot == null || _submitting) return;

    final unansweredIndexes = <int>[];
    final markedIndexes = <int>[];
    for (var i = 0; i < snapshot.questions.length; i++) {
      final key = snapshot.questions[i].answerKey;
      final answered = _answers[key]?.isAnswered ?? false;
      if (!answered) unansweredIndexes.add(i);
      if (_player.markedForReview.contains(key)) {
        markedIndexes.add(i);
      }
    }

    final confirmed = await showSubmitConfirmSheet(
      context: context,
      total: snapshot.questions.length,
      answered: snapshot.questions.length - unansweredIndexes.length,
      unanswered: unansweredIndexes.length,
      marked: markedIndexes.length,
      unansweredIndexes: unansweredIndexes,
      markedIndexes: markedIndexes,
      busy: _submitting,
      onReviewQuestion: _goTo,
    );
    if (!confirmed || !mounted) return;
    await _finalize(reason: 'manual', confirmed: true);
  }

  Future<void> _finalize({
    required String reason,
    required bool confirmed,
  }) async {
    final snapshot = _snapshot;
    if (snapshot == null || _finalized || _submitting) return;
    if (!confirmed) return;

    setState(() => _submitting = true);
    _debounce?.cancel();
    _clock?.cancel();

    try {
      await _persist(
        immediate: true,
        submitReason: reason,
        allowAfterFinalize: true,
      );
      final summary =
          await _tests.finalizeSubmission(snapshot.submissionId);
      if (!mounted) return;
      setState(() => _finalized = true);
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.submissionStatus,
        arguments: SubmissionStatusArgs(
          submissionId: snapshot.submissionId,
          assessmentId: snapshot.assessment.id,
          title: snapshot.assessment.title,
          initialStatus: summary.status,
          includesMedia: _includesMediaAnswers,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _syncClock();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to submit this attempt.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final title = snapshot?.assessment.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Attempt');
    final subtitle = snapshot?.assessment.typeLabel;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    final question = _current;
    final marked = question != null &&
        _player.markedForReview.contains(question.answerKey);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFD),
        body: SafeArea(
          child: Column(
            children: [
              _AttemptHeader(
                title: title,
                subtitle: subtitle,
                submitting: _submitting,
                onBack: () => Navigator.of(context).maybePop(),
                onSubmit: snapshot == null || question == null
                    ? null
                    : _requestSubmit,
                onPalette: snapshot == null || snapshot.questions.isEmpty
                    ? null
                    : () => showCbtPaletteSheet(
                          context: context,
                          questions: snapshot.questions,
                          currentId: question?.answerKey,
                          answers: _answers,
                          player: _player,
                          onSelect: _goTo,
                        ),
                showPaletteButton: !wide,
              ),
              if (snapshot != null)
                _StatsBar(
                  remaining: _remaining,
                  showTimer: _player.deadlineAt != null,
                  totalQuestions: snapshot.questions.length,
                  totalMarks: snapshot.assessment.totalMarks,
                  durationMinutes: snapshot.assessment.durationMinutes,
                ),
              Expanded(child: _buildBody(wide: wide, marked: marked)),
              if (snapshot != null && question != null)
                _AttemptFooter(
                  canPrev: _index > 0,
                  canNext: _index < snapshot.questions.length - 1,
                  autosave: _autosave,
                  submitting: _submitting,
                  onPrev: () => _goTo(_index - 1),
                  onNext: () => _goTo(_index + 1),
                  onClear: _clearAnswer,
                  onSubmit: _requestSubmit,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody({required bool wide, required bool marked}) {
    if (_loading && _snapshot == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2F7BFF)),
      );
    }
    if (_error != null && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F7BFF),
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final questions = _snapshot!.questions;
    if (questions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This assessment has no questions yet.',
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
      );
    }

    final question = _current!;
    final questionCard = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: CbtQuestionBody(
                key: ValueKey(question.answerKey),
                question: question,
                index: _index,
                total: questions.length,
                answer: _answers[question.answerKey],
                onChoice: _selectChoice,
                onTextChanged: _setText,
                onAddImages: question.allowsImageUpload ? _addImages : null,
                onRemoveImage:
                    question.allowsImageUpload ? _removeImage : null,
                isUploading: _uploadingImages,
                uploadProgress: _uploadProgress,
                markedForReview: marked,
                onReviewLater: () => _toggleMark(advance: false),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              ),
            ),
            _TestInfoTile(
              assessment: _snapshot!.assessment,
            ),
          ],
        ),
      ),
    );

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: questionCard,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 7, child: questionCard),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6EAF2)),
                ),
                child: CbtQuestionPalettePanel(
                  questions: questions,
                  currentId: question.answerKey,
                  answers: _answers,
                  player: _player,
                  onSelect: _goTo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptHeader extends StatelessWidget {
  const _AttemptHeader({
    required this.title,
    required this.subtitle,
    required this.submitting,
    required this.onBack,
    required this.onSubmit,
    required this.onPalette,
    required this.showPaletteButton,
  });

  final String title;
  final String? subtitle;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback? onSubmit;
  final VoidCallback? onPalette;
  final bool showPaletteButton;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A2B4C)),
          ),
          const PragyuLogo(height: 28),
          if (!narrow) ...[
            const SizedBox(width: 8),
            const Flexible(
              flex: 2,
              child: Text(
                'Learn • Practice • Grow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: Color(0xFF7A8499),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: Color(0xFF7A8499),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (showPaletteButton)
            IconButton(
              tooltip: 'Question palette',
              onPressed: onPalette,
              icon: const Icon(
                Icons.grid_view_rounded,
                color: Color(0xFF1A2B4C),
              ),
            ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE85D75),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFF5C2CB),
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 10 : 14,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(
              submitting ? 'Submitting…' : 'Submit test',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.remaining,
    required this.showTimer,
    required this.totalQuestions,
    required this.totalMarks,
    required this.durationMinutes,
  });

  final Duration remaining;
  final bool showTimer;
  final int totalQuestions;
  final double? totalMarks;
  final int? durationMinutes;

  @override
  Widget build(BuildContext context) {
    final marksLabel = totalMarks == null
        ? '—'
        : (totalMarks == totalMarks!.roundToDouble()
            ? '${totalMarks!.round()}'
            : '$totalMarks');
    final durationLabel = durationMinutes != null && durationMinutes! > 0
        ? '$durationMinutes min'
        : '—';

    final items = <(IconData, String, String)>[
      if (showTimer)
        (Icons.schedule_rounded, 'Time Left', formatRemaining(remaining)),
      (Icons.description_outlined, 'Questions', '$totalQuestions'),
      (Icons.emoji_events_outlined, 'Total Marks', marksLabel),
      (Icons.timer_outlined, 'Duration', durationLabel),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wrap = constraints.maxWidth < 520;
          if (wrap) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: _StatItem(
                      icon: item.$1,
                      label: item.$2,
                      value: item.$3,
                    ),
                  ),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFFE6EAF2),
                  ),
                Expanded(
                  child: _StatItem(
                    icon: items[i].$1,
                    label: items[i].$2,
                    value: items[i].$3,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F1FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF2F7BFF)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8499),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B4C),
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

class _TestInfoTile extends StatefulWidget {
  const _TestInfoTile({required this.assessment});

  final AssessmentDetail assessment;

  @override
  State<_TestInfoTile> createState() => _TestInfoTileState();
}

class _TestInfoTileState extends State<_TestInfoTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final assessment = widget.assessment;
    final details = <String>[
      assessment.typeLabel,
      if (assessment.durationMinutes != null && assessment.durationMinutes! > 0)
        '${assessment.durationMinutes} min',
      if (assessment.totalMarks != null)
        '${assessment.totalMarks == assessment.totalMarks!.roundToDouble() ? assessment.totalMarks!.round() : assessment.totalMarks} marks',
      if ((assessment.questionsCount ?? assessment.questions.length) > 0)
        '${assessment.questionsCount ?? assessment.questions.length} questions',
    ];

    return Material(
      color: const Color(0xFFF8FAFD),
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF2F7BFF),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Test Information',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1A2B4C),
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF7A8499),
                  ),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 8),
                Text(
                  details.join(' · '),
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: Color(0xFF7A8499),
                    height: 1.4,
                  ),
                ),
                if ((assessment.instructions ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    assessment.instructions!.trim(),
                    softWrap: true,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: Color(0xFF5B6B7C),
                      height: 1.4,
                    ),
                  ),
                ] else if ((assessment.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    assessment.description!.trim(),
                    softWrap: true,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: Color(0xFF5B6B7C),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptFooter extends StatelessWidget {
  const _AttemptFooter({
    required this.canPrev,
    required this.canNext,
    required this.autosave,
    required this.submitting,
    required this.onPrev,
    required this.onNext,
    required this.onClear,
    required this.onSubmit,
  });

  final bool canPrev;
  final bool canNext;
  final CbtAutosaveState autosave;
  final bool submitting;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _autosaveLabel(autosave),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: Color(0xFF7A8499),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 340;
                  final prev = OutlinedButton.icon(
                    onPressed: submitting || !canPrev ? null : onPrev,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F7BFF),
                      side: const BorderSide(color: Color(0xFF2F7BFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Previous'),
                  );
                  final clear = OutlinedButton(
                    onPressed: submitting ? null : onClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F7BFF),
                      side: const BorderSide(color: Color(0xFF2F7BFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Clear Answer'),
                  );
                  final next = FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : (canNext ? onNext : onSubmit),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F7BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      canNext
                          ? Icons.arrow_forward_rounded
                          : Icons.send_rounded,
                      size: 16,
                    ),
                    label: Text(canNext ? 'Next' : 'Submit'),
                  );

                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        clear,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: prev),
                            const SizedBox(width: 8),
                            Expanded(child: next),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      prev,
                      const SizedBox(width: 8),
                      clear,
                      const Spacer(),
                      next,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _autosaveLabel(CbtAutosaveState state) {
    switch (state) {
      case CbtAutosaveState.idle:
        return 'Answers save automatically';
      case CbtAutosaveState.saving:
        return 'Saving…';
      case CbtAutosaveState.saved:
        return 'Saved';
      case CbtAutosaveState.error:
        return 'Save failed — will retry';
    }
  }
}
