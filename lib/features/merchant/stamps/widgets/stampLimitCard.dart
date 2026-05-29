import 'package:flutter/material.dart';

class StampLimitCard extends StatelessWidget {
  const StampLimitCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

