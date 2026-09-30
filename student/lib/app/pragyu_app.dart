import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/session/auth_session_events.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class PragyuApp extends StatefulWidget {
  const PragyuApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<PragyuApp> createState() => _PragyuAppState();
}

class _PragyuAppState extends State<PragyuApp> {
  @override
  void initState() {
    super.initState();
    AuthSessionEvents.onExpired = _onSessionExpired;
  }

  @override
  void dispose() {
    if (AuthSessionEvents.onExpired == _onSessionExpired) {
      AuthSessionEvents.onExpired = null;
    }
    super.dispose();
  }

  void _onSessionExpired() {
    final nav = PragyuApp.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: PragyuApp.navigatorKey,
      title: AppConfig.instance.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
