import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/catalog/domain/wishlist_models.dart';

abstract class WishlistGateway {
  Future<WishlistSnapshot> loadWishlist({int limit = 100});

  Future<void> saveListing(String listingId);

  Future<void> removeListing(String listingId);

  Future<bool> isSaved(String listingId);
}

/// Auth marketplace wishlist — `GET|POST|DELETE /marketplace/me/wishlist`.
class WishlistRepository implements WishlistGateway {
  WishlistRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<WishlistSnapshot> loadWishlist({int limit = 100}) async {
    final session = await _requireSession();
    final envelope = await _api.get(
      '/marketplace/me/wishlist',
      query: {'limit': '$limit'},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final data = _asMap(envelope['data']);
    return WishlistSnapshot.fromJson(data);
  }

  @override
  Future<void> saveListing(String listingId) async {
    final id = listingId.trim();
    if (id.isEmpty) {
      throw ArgumentError('listing_id is required');
    }
    final session = await _requireSession();
    await _api.post(
      '/marketplace/me/wishlist',
      body: {'listing_id': id},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> removeListing(String listingId) async {
    final id = listingId.trim();
    if (id.isEmpty) return;
    final session = await _requireSession();
    await _api.delete(
      '/marketplace/me/wishlist/$id',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<bool> isSaved(String listingId) async {
    final id = listingId.trim();
    if (id.isEmpty) return false;
    final snapshot = await loadWishlist();
    return snapshot.containsListing(id);
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw ApiException(
        code: 'AUTH_REQUIRED',
        message: 'Please sign in again.',
        statusCode: 401,
      );
    }
    return session;
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
