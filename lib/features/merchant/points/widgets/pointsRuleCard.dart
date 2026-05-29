import 'package:flutter/material.dart';

class PointsRuleCard extends StatelessWidget {
  const PointsRuleCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

