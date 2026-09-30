import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
import 'package:student_mobile/features/catalog/presentation/screens/marketplace_unavailable_screen.dart';

/// Ensures marketplace routes only render when access is available.
class MarketplaceRouteGate extends StatefulWidget {
  const MarketplaceRouteGate({
    super.key,
    required this.child,
    this.service,
  });

  final Widget child;
  final MarketplaceAccessService? service;

  @override
  State<MarketplaceRouteGate> createState() => _MarketplaceRouteGateState();
}

class _MarketplaceRouteGateState extends State<MarketplaceRouteGate> {
  late final MarketplaceAccessService _service =
      widget.service ?? MarketplaceAccessService.instance;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _service.ensureLoaded();
    if (mounted) setState(() => _loading = false);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_service.ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }
    if (!_service.available) {
      return MarketplaceUnavailableScreen(reason: _service.reason);
    }
    return widget.child;
  }
}
