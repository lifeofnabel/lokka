import 'package:flutter/material.dart';

class StampProgressCard extends StatelessWidget {
  const StampProgressCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

