import 'package:flutter/material.dart';

class FeedFilterBar extends StatelessWidget {
  const FeedFilterBar({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

