import 'package:flutter/widgets.dart';

/// Fired when access + refresh tokens are no longer usable.
abstract final class AuthSessionEvents {
  static VoidCallback? onExpired;

  static void notifyExpired() {
    final callback = onExpired;
    if (callback == null) return;
    // Defer so callers can finish unwinding the failed request.
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }
}
