import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/share/pragyu_copy.dart';
import 'package:student_mobile/app/share/pragyu_share.dart';
import 'package:student_mobile/app/theme/app_theme.dart';

/// Builds a public share URL compatible with student-web `/share/ai?d=…`.
/// Deep-link path is unchanged — branding lives in the share message only.
String mentorShareLink({
  required String question,
  required String answer,
  String baseUrl = 'https://pragyu.com',
}) {
  final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final payload = jsonEncode({
    'q': question.length > 240 ? question.substring(0, 240) : question,
    'a': _clipMarkdown(answer, 8000),
  });
  final data = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
  return '$base/share/ai?d=$data';
}

String mentorShareMessage(String question) =>
    'Pragyu AI\n\n$question\n\nLearn smarter with Pragyu';

String _clipMarkdown(String value, int limit) {
  if (value.length <= limit) return value;
  final slice = value.substring(0, limit);
  final paragraph = slice.lastIndexOf('\n\n');
  final line = slice.lastIndexOf('\n');
  final cut = paragraph > limit * 0.6
      ? paragraph
      : (line > limit * 0.6 ? line : limit);
  return slice.substring(0, cut).trimRight();
}

/// Canonical Student App share sheet (AI Mentor — reuse pattern elsewhere).
Future<void> showMentorShareSheet(
  BuildContext context, {
  required String question,
  required String answer,
}) {
  const accent = Color(0xFF2F7BFF);
  const soft = Color(0xFFE8F0FF);
  const ink = Color(0xFF1A2B4C);
  const muted = Color(0xFF7A8499);

  final link = mentorShareLink(question: question, answer: answer);
  final text = mentorShareMessage(question);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.ios_share_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share from Pragyu AI',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Share this response with others. Your other chats stay private.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            height: 1.35,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Share link',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        link,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await copyPragyuText(
                        context,
                        text: link,
                        message: PragyuCopyMessages.linkCopied,
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy link'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Share on',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ShareChannelChip(
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    icon: Icons.chat_rounded,
                    onTap: () => _openUri(
                      Uri.parse(
                        'https://wa.me/?text=${Uri.encodeComponent('$text\n$link')}',
                      ),
                    ),
                  ),
                  _ShareChannelChip(
                    label: 'Telegram',
                    color: const Color(0xFF229ED9),
                    icon: Icons.send_rounded,
                    onTap: () => _openUri(
                      Uri.parse(
                        'https://t.me/share/url?url=${Uri.encodeComponent(link)}'
                        '&text=${Uri.encodeComponent(text)}',
                      ),
                    ),
                  ),
                  _ShareChannelChip(
                    label: 'LinkedIn',
                    color: const Color(0xFF0A66C2),
                    icon: Icons.business_center_rounded,
                    onTap: () => _openUri(
                      Uri.parse(
                        'https://www.linkedin.com/sharing/share-offsite/'
                        '?url=${Uri.encodeComponent(link)}',
                      ),
                    ),
                  ),
                  _ShareChannelChip(
                    label: 'Email',
                    color: const Color(0xFF64748B),
                    icon: Icons.mail_outline_rounded,
                    onTap: () {
                      final subject =
                          'Pragyu · ${question.length > 80 ? question.substring(0, 80) : question}';
                      final body = '$text\n\n$link';
                      _openUri(
                        Uri.parse(
                          'mailto:?subject=${Uri.encodeComponent(subject)}'
                          '&body=${Uri.encodeComponent(body)}',
                        ),
                      );
                    },
                  ),
                  _ShareChannelChip(
                    label: 'More…',
                    color: accent,
                    icon: Icons.ios_share_rounded,
                    onTap: () async {
                      await PragyuShare.shareMentor(
                        question: question,
                        link: link,
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                    },
                  ),
                  _ShareChannelChip(
                    label: 'Copy answer',
                    color: ink,
                    icon: Icons.content_copy_rounded,
                    onTap: () async {
                      await copyPragyuText(
                        context,
                        text: brandPragyuCopiedBody(answer, via: 'Pragyu AI'),
                        message: PragyuCopyMessages.answerCopied,
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _openUri(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ShareChannelChip extends StatelessWidget {
  const _ShareChannelChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 88,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2B4C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
