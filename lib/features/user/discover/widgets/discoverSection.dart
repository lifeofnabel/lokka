import 'package:flutter/material.dart';

class DiscoverSection extends StatelessWidget {
  const DiscoverSection({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

