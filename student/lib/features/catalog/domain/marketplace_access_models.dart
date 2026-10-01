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

  /// Used when the access check fails (network, auth, parse). Never opens store.
  static const unknownClosed = MarketplaceAccess(
    available: false,
    ready: true,
    reason: 'Marketplace access could not be verified right now.',
  );

  /// While fetching — treat as unavailable so UI does not flash open.
  static const loading = MarketplaceAccess(available: false, ready: false);

  factory MarketplaceAccess.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MarketplaceAccess.unknownClosed;
    final available = json['available'] != false;
    final reason = json['reason']?.toString();
    return MarketplaceAccess(
      available: available,
      reason: (reason != null && reason.isNotEmpty) ? reason : null,
    );
  }
}
