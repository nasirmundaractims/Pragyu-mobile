import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Cached network image with a quiet error fallback.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.errorIcon = Icons.image_not_supported_outlined,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData errorIcon;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) => ColoredBox(
        color: const Color(0xFFF0F3F8),
        child: SizedBox(width: width, height: height),
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: const Color(0xFFF0F3F8),
        child: Center(
          child: Icon(errorIcon, color: const Color(0xFF9AA3B5)),
        ),
      ),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
