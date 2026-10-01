import 'package:student_mobile/features/catalog/domain/catalog_models.dart';

/// Marketplace wishlist snapshot (slice 5.2 — saved courses).
class WishlistSnapshot {
  const WishlistSnapshot({
    this.items = const [],
    this.count = 0,
  });

  final List<CatalogListing> items;
  final int count;

  bool get isEmpty => items.isEmpty;

  bool containsListing(String listingId) {
    final id = listingId.trim();
    if (id.isEmpty) return false;
    return items.any((item) => item.id == id);
  }

  WishlistSnapshot withAdded(CatalogListing listing) {
    if (containsListing(listing.id)) return this;
    final next = [listing, ...items];
    return WishlistSnapshot(items: next, count: next.length);
  }

  WishlistSnapshot withoutListing(String listingId) {
    final id = listingId.trim();
    final next = items.where((item) => item.id != id).toList(growable: false);
    return WishlistSnapshot(items: next, count: next.length);
  }

  factory WishlistSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <CatalogListing>[];
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is! Map) continue;
        final map = row.map((k, v) => MapEntry(k.toString(), v));
        final listing = CatalogListing.fromJson(map);
        if (listing.id.isEmpty) continue;
        items.add(listing);
      }
    }
    final countRaw = json['count'];
    final count = countRaw is int
        ? countRaw
        : int.tryParse(countRaw?.toString() ?? '') ?? items.length;
    return WishlistSnapshot(items: items, count: count);
  }
}
