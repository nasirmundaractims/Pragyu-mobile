/// Slice 5.1 / Phase 6 — how eval / class reminders reach the student.
///
/// Channel preferences (S-75) are live. OS push is available when the backend
/// reports `capabilities.push.configured` (FCM driver + server key).
/// Until then, evaluation.completed and learning.live_class_reminder still
/// arrive in the Alerts inbox (in-app).
abstract final class PushDelivery {
  /// Overridden at runtime from GET /notifications/preferences capabilities.
  static bool osPushAvailable = false;

  static String get pushChannelSubtitle => osPushAvailable
      ? 'Device banners for tests, scores, and class reminders'
      : 'Preference saved for later — device banners aren’t live yet';

  static const String arrivalTitle = 'Where alerts arrive today';

  static String get arrivalBody => osPushAvailable
      ? 'Evaluation complete and class reminders can arrive as device push '
          'when Push is enabled. They also stay in Alerts.'
      : 'Evaluation complete and class reminders show in Alerts. '
          'Turn on In-app alerts so you don’t miss them. '
          'Device push will activate when store push is enabled.';

  static const String openAlertsLabel = 'Open Alerts';

  static String get pushEnabledSnack => osPushAvailable
      ? 'Push enabled. Keep the app permissions allowed for banners.'
      : 'Preference saved. Eval and class reminders still arrive in Alerts until device push is live.';
}
