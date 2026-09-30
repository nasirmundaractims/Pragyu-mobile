import 'package:flutter/foundation.dart';

import 'package:student_mobile/features/catalog/data/marketplace_access_repository.dart';
import 'package:student_mobile/features/catalog/domain/marketplace_access_models.dart';

/// App-wide marketplace visibility cache (TTL ~60s), fail-open on errors.
class MarketplaceAccessService extends ChangeNotifier {
  MarketplaceAccessService({MarketplaceAccessGateway? gateway})
      : _gateway = gateway ?? MarketplaceAccessRepository();

  static final MarketplaceAccessService instance = MarketplaceAccessService();

  final MarketplaceAccessGateway _gateway;

  MarketplaceAccess _access = MarketplaceAccess.loading;
  DateTime? _fetchedAt;
  Future<void>? _inFlight;

  static const _ttl = Duration(seconds: 60);

  MarketplaceAccess get access => _access;

  bool get available => _access.available;

  bool get ready => _access.ready;

  String? get reason => _access.reason;

  Future<void> ensureLoaded({bool force = false}) {
    if (!force &&
        _access.ready &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _ttl) {
      return Future<void>.value();
    }
    return refresh(force: force);
  }

  Future<void> refresh({bool force = false}) {
    if (_inFlight != null && !force) return _inFlight!;
    final future = _doRefresh();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _doRefresh() async {
    try {
      final next = await _gateway.fetch();
      _access = next;
    } catch (_) {
      // Fail-open when offline / config missing (e.g. widget tests).
      _access = MarketplaceAccess.unknownOpen;
    }
    _fetchedAt = DateTime.now();
    notifyListeners();
  }

  /// Clears cache (e.g. on org switch / logout).
  void reset() {
    _access = MarketplaceAccess.loading;
    _fetchedAt = null;
    _inFlight = null;
    notifyListeners();
  }
}
