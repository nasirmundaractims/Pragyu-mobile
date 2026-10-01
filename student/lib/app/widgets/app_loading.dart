import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/student_hub_colors.dart';

/// Shared loading indicator for Student App screens.
///
/// Set [scrollable] when the parent is a [RefreshIndicator] that needs a
/// scrollable child even while loading (hub list pattern).
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.scrollable = false,
    this.padding = const EdgeInsets.symmetric(vertical: 140),
  });

  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const indicator = CircularProgressIndicator(color: StudentHubColors.blue);

    if (scrollable) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: padding,
            child: const Center(child: indicator),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: padding,
        child: indicator,
      ),
    );
  }
}
