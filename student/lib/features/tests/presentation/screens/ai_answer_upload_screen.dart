import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/ai_answer_upload_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';

/// Dedicated AI evaluation answer-sheet upload screen (camera + gallery).
///
/// Recreates the Pragyu "Upload Answer for Question" reference with real widgets.
class AiAnswerUploadScreen extends StatefulWidget {
  const AiAnswerUploadScreen({
    super.key,
    required this.args,
    this.testsRepository,
  });

  final AiAnswerUploadArgs args;
  final TestsGateway? testsRepository;

  @override
  State<AiAnswerUploadScreen> createState() => _AiAnswerUploadScreenState();
}

class _AiAnswerUploadScreenState extends State<AiAnswerUploadScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _pageBg = Color(0xFFF8FAFD);
  static const _purple = Color(0xFF9B6BFF);
  static const _dash = Color(0xFF9EC0FF);

  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();
  final _picker = ImagePicker();

  late List<AnswerImageAttachment> _images;
  late final TextEditingController _textController;
  bool _uploading = false;
  int _uploadProgress = 0;
  bool _submitting = false;
  bool _reorderMode = false;

  @override
  void initState() {
    super.initState();
    _images = _copyImages(widget.args.existingImages);
    _textController = TextEditingController(text: widget.args.existingText ?? '');
  }

  @override
  void reassemble() {
    super.reassemble();
    final dynamic raw = _images;
    if (raw is! List<AnswerImageAttachment>) {
      _images = const <AnswerImageAttachment>[];
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  static List<AnswerImageAttachment> _copyImages(List<AnswerImageAttachment>? raw) {
    if (raw == null || raw.isEmpty) return <AnswerImageAttachment>[];
    return List<AnswerImageAttachment>.from(raw);
  }

  List<AnswerImageAttachment> get _safeImages {
    try {
      final dynamic raw = _images;
      if (raw == null) return const <AnswerImageAttachment>[];
      if (raw is! List) return const <AnswerImageAttachment>[];
      return List<AnswerImageAttachment>.from(
        raw.whereType<AnswerImageAttachment>(),
      );
    } catch (_) {
      return const <AnswerImageAttachment>[];
    }
  }

  List<String> get _chips {
    final fromArgs = widget.args.tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    if (fromArgs.isNotEmpty) return fromArgs;

    final q = widget.args.question;
    final chips = <String>[];
    final type = (q.effectiveType ?? q.type ?? '').trim();
    if (type.isNotEmpty) {
      chips.add(_prettyType(type));
    } else {
      chips.add('Descriptive');
    }
    if (q.wordLimit != null && q.wordLimit! > 0) {
      chips.add('${q.wordLimit} words');
    }
    chips.add('AI scored');
    return chips;
  }

  static String _prettyType(String raw) {
    final lower = raw.toLowerCase().replaceAll('-', '_');
    if (lower.contains('long') ||
        lower.contains('essay') ||
        lower.contains('descriptive') ||
        lower.contains('subjective')) {
      return 'Long answer';
    }
    if (lower.contains('short')) return 'Short answer';
    return raw.replaceAll('_', ' ');
  }

  bool get _isMultiQuestion => widget.args.questionTotal > 1;

  String get _submitButtonLabel {
    if (!widget.args.finalizeOnSubmit) return 'Save answer pages';
    if (_isMultiQuestion) {
      return 'Submit all answers for AI';
    }
    return 'Submit for AI Evaluation';
  }

  String get _submitDialogBody {
    if (_isMultiQuestion) {
      return 'This submits the whole attempt (${widget.args.questionTotal} questions), '
          'not just this page. Evaluation runs in the background — we will notify you when scores are ready.';
    }
    return 'Your answer was submitted successfully. '
        'Evaluation is processing in the background. '
        'We will notify you when it is ready.';
  }

  String get _questionText {
    final html = widget.args.question.contentHtml?.trim();
    final plain = widget.args.question.content?.trim();
    final raw = (plain != null && plain.isNotEmpty)
        ? plain
        : (html ?? '').replaceAll(RegExp(r'<[^>]*>'), ' ');
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _pick(ImageSource source) async {
    if (_uploading || _submitting) return;

    List<XFile> files;
    if (source == ImageSource.gallery) {
      files = await _picker.pickMultiImage(imageQuality: 85);
    } else {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      files = photo == null ? const [] : [photo];
    }
    if (files.isEmpty || !mounted) return;
    await _uploadFiles(files);
  }

  Future<void> _uploadFiles(List<XFile> files) async {
    final batch = files.take(12).toList(growable: false);
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    final uploaded = <AnswerImageAttachment>[..._images];
    final startPage = uploaded.length + 1;

    try {
      for (var i = 0; i < batch.length; i++) {
        final file = batch[i];
        final bytes = await file.readAsBytes();
        final attachment = await _tests.uploadAnswerImage(
          submissionId: widget.args.submissionId,
          bytes: bytes,
          fileName: file.name.isNotEmpty ? file.name : 'answer-${i + 1}.jpg',
          mimeType: file.mimeType ?? 'image/jpeg',
          pageNumber: startPage + i,
        );
        uploaded.add(attachment);
        if (!mounted) return;
        setState(() {
          _uploadProgress = (((i + 1) / batch.length) * 100).round();
          _images = List<AnswerImageAttachment>.from(uploaded);
        });
      }
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            batch.length == 1
                ? 'Answer page uploaded.'
                : '${batch.length} answer pages uploaded.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
        _images = uploaded;
      });
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
    setState(() {
      _images = _images
          .where((image) => image.mediaFileId != mediaFileId)
          .toList(growable: false);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  Future<void> _onSubmit() async {
    if (_images.isEmpty || _submitting || _uploading) return;

    if (!widget.args.finalizeOnSubmit) {
      Navigator.of(context).pop(
        AiAnswerUploadResult(
          images: _images,
          text: _textController.text.trim().isEmpty
              ? null
              : _textController.text.trim(),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _tests.finalizeSubmission(widget.args.submissionId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(
              _isMultiQuestion ? 'Attempt submitted' : 'Answer submitted',
            ),
            content: Text(_submitDialogBody),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        AiAnswerUploadResult(
          images: _images,
          text: _textController.text.trim().isEmpty
              ? null
              : _textController.text.trim(),
          finalized: true,
          submissionStatus: 'ready_for_evaluation',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to submit for AI evaluation.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload tips',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Capture each page clearly, keep text inside the frame, '
                  'and upload pages in order. AI OCR reads your handwriting '
                  'after you submit.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: _muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _popWithImages() {
    Navigator.of(context).pop(
      AiAnswerUploadResult(
        images: _images,
        text: _textController.text.trim().isEmpty
            ? null
            : _textController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 380;
    final marks = widget.args.question.maxMarks;
    final marksLabel = marks == null
        ? null
        : (marks == marks.roundToDouble()
            ? '${marks.round()} Marks'
            : '${marks.toStringAsFixed(1)} Marks');
    final canSubmit = _safeImages.isNotEmpty && !_uploading && !_submitting;
    final pages = _safeImages;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: _popWithImages,
                onHelp: _showHelp,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    narrow ? 16 : 20,
                    8,
                    narrow ? 16 : 20,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    _HeroBanner(narrow: narrow),
                    const SizedBox(height: 16),
                    _QuestionCard(
                      index: widget.args.questionIndex,
                      total: widget.args.questionTotal,
                      marksLabel: marksLabel,
                      questionText: _questionText.isEmpty
                          ? 'Answer this question by uploading clear photos of your written pages.'
                          : _questionText,
                      chips: _chips,
                    ),
                    const SizedBox(height: 16),
                    _UploadZone(
                      uploading: _uploading,
                      progress: _uploadProgress,
                      onCamera: () => _pick(ImageSource.camera),
                      onGallery: () => _pick(ImageSource.gallery),
                      narrow: narrow,
                    ),
                    const SizedBox(height: 18),
                    _UploadedPagesHeader(
                      count: pages.length,
                      reorderMode: _reorderMode,
                      onToggleReorder: pages.length < 2
                          ? null
                          : () => setState(() => _reorderMode = !_reorderMode),
                    ),
                    const SizedBox(height: 10),
                    if (pages.isEmpty)
                      const _EmptyPages()
                    else if (_reorderMode)
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pages.length,
                        onReorderItem: _reorder,
                        itemBuilder: (context, index) {
                          final image = pages[index];
                          return _PageTile(
                            key: ValueKey(image.mediaFileId),
                            index: index,
                            label: image.fileName,
                            pageNumber: image.pageNumber ?? (index + 1),
                            reorderable: true,
                            onRemove: () => _removeImage(image.mediaFileId),
                          );
                        },
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < pages.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _PageTile(
                                index: i,
                                label: pages[i].fileName,
                                pageNumber: pages[i].pageNumber ?? (i + 1),
                                reorderable: false,
                                onRemove: () =>
                                    _removeImage(pages[i].mediaFileId),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const _TipsCard(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText:
                            'Optional: type a short typed answer or notes',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE6EAF2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE6EAF2)),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 16 : 20,
                  8,
                  narrow ? 16 : 20,
                  12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: canSubmit ? _onSubmit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      disabledBackgroundColor: const Color(0xFFB7C9E8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _submitButtonLabel,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontWeight: FontWeight.w800,
                                    fontSize: narrow ? 14 : 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onHelp});

  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: _AiAnswerUploadScreenState._ink,
          ),
          const Expanded(
            child: Text(
              'Upload Answer for Question',
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 2,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _AiAnswerUploadScreenState._ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Help',
            onPressed: onHelp,
            icon: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _AiAnswerUploadScreenState._ink.withValues(alpha: 0.35),
                  width: 1.4,
                ),
              ),
              child: const Text(
                '?',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _AiAnswerUploadScreenState._ink,
                  height: 1,
                ),
              ),
            ),
            color: _AiAnswerUploadScreenState._ink,
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 14 : 16, 14, narrow ? 10 : 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F8FF), Color(0xFFEAF2FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PragyuLogo(height: 40),
                SizedBox(height: 8),
                Text(
                  'Your Answers. Smarter Feedback.',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: _AiAnswerUploadScreenState._ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: narrow ? 88 : 108,
              maxHeight: narrow ? 88 : 108,
            ),
            child: const _ScanIllustration(),
          ),
        ],
      ),
    );
  }
}

class _ScanIllustration extends StatelessWidget {
  const _ScanIllustration();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _AiAnswerUploadScreenState._blue.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 58,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD6E4FF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == 1
                          ? _AiAnswerUploadScreenState._blue
                          : const Color(0xFFD9E4F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 4,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _AiAnswerUploadScreenState._blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.total,
    required this.questionText,
    required this.chips,
    this.marksLabel,
  });

  final int index;
  final int total;
  final String questionText;
  final List<String> chips;
  final String? marksLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total > 1
                      ? 'Question ${index + 1} of $total'
                      : 'Question ${index + 1}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _AiAnswerUploadScreenState._blue,
                  ),
                ),
              ),
              if (marksLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _AiAnswerUploadScreenState._blueSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    marksLabel!,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _AiAnswerUploadScreenState._blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            questionText,
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.4,
              color: _AiAnswerUploadScreenState._ink,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3F8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chip,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _AiAnswerUploadScreenState._muted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadZone extends StatelessWidget {
  const _UploadZone({
    required this.uploading,
    required this.progress,
    required this.onCamera,
    required this.onGallery,
    required this.narrow,
  });

  final bool uploading;
  final int progress;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: _AiAnswerUploadScreenState._dash,
        radius: 18,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          narrow ? 14 : 16,
          18,
          narrow ? 14 : 16,
          16,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 36,
              color: _AiAnswerUploadScreenState._blue,
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload Your Answer Sheet',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _AiAnswerUploadScreenState._blue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Take a photo or select images of your written answer.',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                height: 1.35,
                color: _AiAnswerUploadScreenState._muted,
              ),
            ),
            const SizedBox(height: 14),
            if (narrow)
              Column(
                children: [
                  _SourceCard(
                    icon: Icons.photo_camera_outlined,
                    iconColor: _AiAnswerUploadScreenState._blue,
                    title: 'Open Camera',
                    subtitle: 'Take a photo now',
                    onTap: uploading ? null : onCamera,
                  ),
                  const SizedBox(height: 10),
                  _SourceCard(
                    icon: Icons.photo_library_outlined,
                    iconColor: _AiAnswerUploadScreenState._purple,
                    title: 'Select from Gallery',
                    subtitle: 'Choose from device',
                    onTap: uploading ? null : onGallery,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _SourceCard(
                      icon: Icons.photo_camera_outlined,
                      iconColor: _AiAnswerUploadScreenState._blue,
                      title: 'Open Camera',
                      subtitle: 'Take a photo now',
                      onTap: uploading ? null : onCamera,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SourceCard(
                      icon: Icons.photo_library_outlined,
                      iconColor: _AiAnswerUploadScreenState._purple,
                      title: 'Select from Gallery',
                      subtitle: 'Choose from device',
                      onTap: uploading ? null : onGallery,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFD6E4FF))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'or',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: _AiAnswerUploadScreenState._muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFD6E4FF))),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Add pages with camera or gallery',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                color: _AiAnswerUploadScreenState._muted,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Supports: JPG, PNG | Max size: 10 MB per file',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                color: _AiAnswerUploadScreenState._muted,
              ),
            ),
            if (uploading) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress <= 0 ? null : progress / 100,
                  minHeight: 6,
                  color: _AiAnswerUploadScreenState._blue,
                  backgroundColor: const Color(0xFFD6E4FF),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Uploading… $progress%',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: _AiAnswerUploadScreenState._muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: _AiAnswerUploadScreenState._ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  color: _AiAnswerUploadScreenState._muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadedPagesHeader extends StatelessWidget {
  const _UploadedPagesHeader({
    required this.count,
    required this.reorderMode,
    required this.onToggleReorder,
  });

  final int count;
  final bool reorderMode;
  final VoidCallback? onToggleReorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Uploaded Pages ($count)',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _AiAnswerUploadScreenState._ink,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onToggleReorder,
          icon: Icon(
            reorderMode ? Icons.check_rounded : Icons.swap_vert_rounded,
            size: 18,
          ),
          label: Text(reorderMode ? 'Done' : 'Reorder'),
          style: TextButton.styleFrom(
            foregroundColor: onToggleReorder == null
                ? _AiAnswerUploadScreenState._muted
                : _AiAnswerUploadScreenState._blue,
          ),
        ),
      ],
    );
  }
}

class _EmptyPages extends StatelessWidget {
  const _EmptyPages();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 34,
            color: Color(0xFFA8B6C9),
          ),
          SizedBox(height: 10),
          Text(
            'No images uploaded yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: _AiAnswerUploadScreenState._ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add images of your answer sheet to continue.',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              height: 1.35,
              color: _AiAnswerUploadScreenState._muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    super.key,
    required this.index,
    required this.label,
    required this.pageNumber,
    required this.reorderable,
    required this.onRemove,
  });

  final int index;
  final String label;
  final int pageNumber;
  final bool reorderable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Row(
          children: [
            if (reorderable)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.drag_handle_rounded, color: _AiAnswerUploadScreenState._muted),
              ),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _AiAnswerUploadScreenState._blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pageNumber',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  color: _AiAnswerUploadScreenState._blue,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.isEmpty ? 'Page $pageNumber' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                  color: _AiAnswerUploadScreenState._ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              color: _AiAnswerUploadScreenState._muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    const tips = [
      'Ensure pages are clear and well-lit',
      'Keep text within page boundaries',
      'Upload all pages in correct order',
      'Avoid blur and shadows',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _AiAnswerUploadScreenState._blueSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: _AiAnswerUploadScreenState._blue,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tips for better evaluation',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _AiAnswerUploadScreenState._blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      color: _AiAnswerUploadScreenState._blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        height: 1.35,
                        color: _AiAnswerUploadScreenState._ink,
                      ),
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

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 6;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
