import 'package:flutter/material.dart';

import 'package:student_mobile/core/config/app_config.dart';

/// Shared Pragyu brand mark — transparent wordmark used across the app.
class PragyuLogo extends StatelessWidget {
  const PragyuLogo({
    super.key,
    this.height = 52,
    this.light = false,
    this.alignment = Alignment.centerLeft,
    this.semanticsLabel,
  });

  static const wordmarkAsset = 'assets/images/brand/pragyu-wordmark.png';
  static const wordmarkLightAsset =
      'assets/images/brand/pragyu-wordmark-light.png';

  /// Default header / chrome logo height (larger for clearer brand presence).
  static const double headerHeight = 48;

  /// Auth / welcome hero logo height.
  static const double heroHeight = 64;

  /// Compact toolbar logo height.
  static const double compactHeight = 40;

  final double height;
  final bool light;
  final Alignment alignment;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticsLabel ?? AppConfig.instance.appName;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final resolvedHeight = (height * scale.clamp(1.0, 1.25)).clamp(
      height,
      height * 1.25,
    );

    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          light ? wordmarkLightAsset : wordmarkAsset,
          height: resolvedHeight,
          fit: BoxFit.contain,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, error, stackTrace) => Text(
            label,
            style: TextStyle(
              fontSize: resolvedHeight * 0.55,
              fontWeight: FontWeight.w800,
              color: light ? Colors.white : const Color(0xFF1A2B4C),
            ),
          ),
        ),
      ),
    );
  }
}
