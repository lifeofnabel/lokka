import 'package:flutter/material.dart';

class PointsProgressCard extends StatelessWidget {
  const PointsProgressCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

