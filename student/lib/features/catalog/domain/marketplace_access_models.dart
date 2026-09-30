/// Result of `GET /students/me/marketplace-access`.
class MarketplaceAccess {
  const MarketplaceAccess({
    required this.available,
    this.reason,
    this.ready = true,
  });

  final bool available;
  final String? reason;
  final bool ready;

  static const unknownOpen = MarketplaceAccess(available: true, ready: true);

  static const loading = MarketplaceAccess(available: true, ready: false);

  factory MarketplaceAccess.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MarketplaceAccess.unknownOpen;
    final available = json['available'] != false;
    final reason = json['reason']?.toString();
    return MarketplaceAccess(
      available: available,
      reason: (reason != null && reason.isNotEmpty) ? reason : null,
    );
  }
}
