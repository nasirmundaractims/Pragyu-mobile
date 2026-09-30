import 'package:student_mobile/app/theme/student_hub_colors.dart';

/// Pragyu Student brand colors — aligned to the hub palette (Phase 3).
///
/// Prefer [StudentHubColors] for new polished screens; [AppColors] remains for
/// legacy call sites and shared widgets.
abstract final class AppColors {
  static const brand = StudentHubColors.blue;
  static const brandSoft = StudentHubColors.blueSoft;
  static const accent = StudentHubColors.blue;
  static const background = StudentHubColors.pageBg;
  static const surface = StudentHubColors.surface;
  static const ink = StudentHubColors.ink;
  static const muted = StudentHubColors.muted;
  static const success = StudentHubColors.success;
  static const danger = StudentHubColors.danger;
}
