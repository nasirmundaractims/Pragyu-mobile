import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
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
    final title = _snapshot?.assessment.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Attempt');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
          actions: [
            if (_player.deadlineAt != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    formatRemaining(_remaining),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _remaining.inMinutes < 5
                          ? AppColors.danger
                          : AppColors.ink,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Question palette',
              onPressed: _snapshot == null || _snapshot!.questions.isEmpty
                  ? null
                  : () => showCbtPaletteSheet(
                        context: context,
                        questions: _snapshot!.questions,
                        currentId: _current?.answerKey,
                        answers: _answers,
                        player: _player,
                        onSelect: _goTo,
                      ),
              icon: const Icon(Icons.grid_view_rounded),
            ),
          ],
        ),
        body: SafeArea(child: _buildBody()),
        bottomNavigationBar: _snapshot == null || _current == null
            ? null
            : _Footer(
                canPrev: _index > 0,
                canNext: _index < (_snapshot!.questions.length - 1),
                marked: _player.markedForReview
                    .contains(_current!.answerKey),
                autosave: _autosave,
                submitting: _submitting,
                onPrev: () => _goTo(_index - 1),
                onNext: () => _goTo(_index + 1),
                onClear: _clearAnswer,
                onMark: () => _toggleMark(advance: true),
                onSubmit: _requestSubmit,
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
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
    return CbtQuestionBody(
      key: ValueKey(question.answerKey),
      question: question,
      index: _index,
      total: questions.length,
      answer: _answers[question.answerKey],
      onChoice: _selectChoice,
      onTextChanged: _setText,
      onAddImages: question.allowsImageUpload ? _addImages : null,
      onRemoveImage: question.allowsImageUpload ? _removeImage : null,
      isUploading: _uploadingImages,
      uploadProgress: _uploadProgress,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.canPrev,
    required this.canNext,
    required this.marked,
    required this.autosave,
    required this.submitting,
    required this.onPrev,
    required this.onNext,
    required this.onClear,
    required this.onMark,
    required this.onSubmit,
  });

  final bool canPrev;
  final bool canNext;
  final bool marked;
  final CbtAutosaveState autosave;
  final bool submitting;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClear;
  final VoidCallback onMark;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _autosaveLabel(autosave),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: submitting || !canPrev ? null : onPrev,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  TextButton(
                    onPressed: submitting ? null : onClear,
                    child: const Text('Clear'),
                  ),
                  TextButton(
                    onPressed: submitting ? null : onMark,
                    child: Text(marked ? 'Unmark' : 'Mark'),
                  ),
                  const Spacer(),
                  if (canNext)
                    FilledButton(
                      onPressed: submitting ? null : onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                      ),
                      child: const Text('Next'),
                    )
                  else
                    FilledButton(
                      onPressed: submitting ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                      ),
                      child: Text(submitting ? 'Submitting…' : 'Submit'),
                    ),
                ],
              ),
              if (canNext) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: submitting ? null : onSubmit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.brandSoft),
                    ),
                    child: const Text('Submit test'),
                  ),
                ),
              ],
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
