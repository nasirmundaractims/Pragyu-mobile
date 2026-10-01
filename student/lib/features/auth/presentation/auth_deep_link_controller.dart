import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:student_mobile/app/pragyu_app.dart';
import 'package:student_mobile/features/auth/domain/auth_deep_link_resolver.dart';

/// Listens for auth email / app links and navigates to reset or verify screens.
class AuthDeepLinkController {
  AuthDeepLinkController({
    Stream<Uri>? uriStream,
    AppLinks? appLinks,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _uriStream = uriStream,
        _appLinks = appLinks,
        _navigatorKey = navigatorKey ?? PragyuApp.navigatorKey;

  static AuthDeepLinkController? _instance;

  /// Shared controller started from [PragyuApp].
  static AuthDeepLinkController get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AuthDeepLinkController has not been started.');
    }
    return value;
  }

  static bool get isStarted => _instance != null;

  /// Test / DI helper — replaces the shared instance.
  @visibleForTesting
  static void debugSetInstance(AuthDeepLinkController? controller) {
    _instance = controller;
  }

  final Stream<Uri>? _uriStream;
  final AppLinks? _appLinks;
  final GlobalKey<NavigatorState> _navigatorKey;

  StreamSubscription<Uri>? _subscription;
  AuthDeepLinkTarget? _pending;
  bool _navigationReady = false;

  /// Starts listening for initial + subsequent app links.
  Future<void> start() async {
    _instance = this;
    await _subscription?.cancel();
    try {
      final stream = _uriStream ?? (_appLinks ?? AppLinks()).uriLinkStream;
      _subscription = stream.listen(
        handleUri,
        onError: (Object error, StackTrace stack) {
          if (kDebugMode) {
            debugPrint('AuthDeepLinkController stream error: $error');
          }
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AuthDeepLinkController start failed: $error');
      }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    if (identical(_instance, this)) {
      _instance = null;
    }
  }

  /// Call once splash (or first route) has finished its replacement navigation.
  void markNavigationReady() {
    _navigationReady = true;
    _flushPending();
  }

  /// Consumes a pending target without navigating (used by splash).
  AuthDeepLinkTarget? consumePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  @visibleForTesting
  AuthDeepLinkTarget? get debugPending => _pending;

  void handleUri(Uri uri) {
    final target = AuthDeepLinkResolver.resolve(uri);
    if (target == null) return;

    if (!_navigationReady || _navigatorKey.currentState == null) {
      _pending = target;
      return;
    }

    _navigate(target);
  }

  void _flushPending() {
    final pending = _pending;
    if (pending == null) return;
    if (!_navigationReady || _navigatorKey.currentState == null) return;
    _pending = null;
    _navigate(pending);
  }

  void _navigate(AuthDeepLinkTarget target) {
    final nav = _navigatorKey.currentState;
    if (nav == null) {
      _pending = target;
      return;
    }
    nav.pushNamed(target.route, arguments: target.arguments);
  }
}
