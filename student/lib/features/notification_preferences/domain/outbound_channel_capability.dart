/// Runtime capability flags for optional outbound channels (Phase 6/8).
/// Synced from GET /notifications/preferences capabilities.
class OutboundChannelCapability {
  OutboundChannelCapability._();

  static bool smsConfigured = false;
  static bool whatsappConfigured = false;

  static String get smsSubtitle => smsConfigured
      ? 'Critical reminders by text message'
      : 'SMS will activate when a provider is configured on the server.';

  static String get whatsappSubtitle => whatsappConfigured
      ? 'Updates via WhatsApp when you opt in'
      : 'WhatsApp will activate when a provider is configured on the server.';
}
