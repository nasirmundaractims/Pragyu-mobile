import 'package:flutter/material.dart';

/// Established Student App hub palette (Home, Tests Hub, Result Feedback).
///
/// Prefer these over legacy [AppColors] navy tokens for polished screens.
abstract final class StudentHubColors {
  static const ink = Color(0xFF1A2B4C);
  static const muted = Color(0xFF7A8499);
  static const blue = Color(0xFF2F7BFF);
  static const blueSoft = Color(0xFFE8F1FF);
  static const pageBg = Color(0xFFF8FAFD);
  static const border = Color(0xFFE6EAF2);
  static const surface = Color(0xFFFFFFFF);
  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF22A06B);
  static const successSoft = Color(0xFFE8F8EF);
  static const orangeSoft = Color(0xFFFFF1E0);
  static const redSoft = Color(0xFFFDECEC);

  /// Default card / panel corner radius in hub screens.
  static const double cardRadius = 16;
}
