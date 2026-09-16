import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// In-app PDF surface for S-28 (falls back gracefully on load errors).
class PdfDocumentViewer extends StatelessWidget {
  const PdfDocumentViewer({
    super.key,
    required this.url,
    this.height = 420,
  });

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return _ErrorBox(height: height, message: 'Invalid PDF link.');
    }

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: PdfViewer.uri(
        uri,
        params: PdfViewerParams(
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            return _ErrorBox(
              height: height,
              message: 'Could not load PDF preview. Use Open instead.',
            );
          },
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.height, required this.message});

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ),
      ),
    );
  }
}
