import 'package:flutter/material.dart';

class ScannerCard extends StatelessWidget {
  const ScannerCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

