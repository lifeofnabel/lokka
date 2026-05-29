import 'package:flutter/material.dart';

class FeedActionButtons extends StatelessWidget {
  const FeedActionButtons({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

