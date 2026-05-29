import 'package:flutter/material.dart';

class ClaimStatusCard extends StatelessWidget {
  const ClaimStatusCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

