import 'package:flutter/material.dart';

import 'package:student_mobile/core/config/app_config.dart';

/// Shared Pragyu brand mark — same wordmark as the welcome screen.
class PragyuLogo extends StatelessWidget {
  const PragyuLogo({
    super.key,
    this.height = 40,
    this.light = false,
    this.alignment = Alignment.centerLeft,
    this.semanticsLabel,
  });

  static const wordmarkAsset = 'assets/images/brand/pragyu-wordmark.png';
  static const wordmarkLightAsset =
      'assets/images/brand/pragyu-wordmark-light.png';

  final double height;
  final bool light;
  final Alignment alignment;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticsLabel ?? AppConfig.instance.appName;
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          light ? wordmarkLightAsset : wordmarkAsset,
          height: height,
          fit: BoxFit.contain,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, error, stackTrace) => Text(
            label,
            style: TextStyle(
              fontSize: height * 0.55,
              fontWeight: FontWeight.w800,
              color: light ? Colors.white : const Color(0xFF1A2B4C),
            ),
          ),
        ),
      ),
    );
  }
}
