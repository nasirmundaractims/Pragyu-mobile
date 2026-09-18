import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// Renders CBT stem / choice / passage content.
///
/// Prefers structured plain text derived from HTML (paragraphs / line breaks
/// preserved). Full KaTeX / scripted HTML is not supported on mobile yet.
class CbtRichContent extends StatelessWidget {
  const CbtRichContent({
    super.key,
    required this.content,
    this.html,
    this.compact = false,
  });

  final String? content;
  final String? html;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = _displayText(html: html, fallback: content);
    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      style: TextStyle(
        fontSize: compact ? 14 : 17,
        fontWeight: compact ? FontWeight.w500 : FontWeight.w600,
        color: AppColors.ink,
        height: 1.4,
      ),
    );
  }

  static String _displayText({String? html, String? fallback}) {
    final rawHtml = html?.trim();
    if (rawHtml != null && rawHtml.isNotEmpty) {
      final fromHtml = htmlToReadableText(rawHtml);
      if (fromHtml.isNotEmpty) return fromHtml;
    }
    return (fallback ?? '').trim();
  }
}

/// Converts simple question HTML into readable plain text.
String htmlToReadableText(String html) {
  var value = html;
  value = value.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  value = value.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
  value = value.replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n');
  value = value.replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');
  value = value.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
  value = value.replaceAll(RegExp(r'<[^>]+>'), ' ');
  value = value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  value = value.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  value = value.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  value = value.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  return value.trim();
}

/// Image URLs embedded in HTML (`<img src="...">`).
List<String> extractHtmlImageUrls(String? html) {
  if (html == null || html.trim().isEmpty) return const [];
  final matches = RegExp(
    r'''<img[^>]+src=["']([^"']+)["']''',
    caseSensitive: false,
  ).allMatches(html);
  return matches
      .map((m) => m.group(1)?.trim() ?? '')
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}
