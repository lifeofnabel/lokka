import 'package:flutter/material.dart';

import '../theme/appMotion.dart';

/// Fade + rise entrance for one item in a staggered group. All siblings
/// share one clock (`AppMotion.entrance`); each starts a beat later via
/// [index], so a column of elements cascades in instead of popping together.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * AppMotion.staggerStep).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.entrance,
      curve: Interval(start, 1.0, curve: AppMotion.strongEaseOut),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
