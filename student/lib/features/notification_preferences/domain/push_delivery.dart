/// Slice 5.1 — how eval / class reminders reach the student.
///
/// Channel preferences (S-75) are live. OS push (FCM/APNs) stays deferred
/// until a device-token API and production push driver exist on the backend.
/// Until then, evaluation.completed and learning.live_class_reminder arrive
/// in the Alerts inbox (in-app).
abstract final class PushDelivery {
  /// False until FCM token registration + backend push driver ship.
  static const bool osPushAvailable = false;

  static const String pushChannelSubtitle =
      'Preference saved for later — device banners aren’t live yet';

  static const String arrivalTitle = 'Where alerts arrive today';

  static const String arrivalBody =
      'Evaluation complete and class reminders show in Alerts. '
      'Turn on In-app alerts so you don’t miss them. '
      'Device push will activate when store push is enabled.';

  static const String openAlertsLabel = 'Open Alerts';

  static const String pushEnabledSnack =
      'Preference saved. Eval and class reminders still arrive in Alerts until device push is live.';
}
