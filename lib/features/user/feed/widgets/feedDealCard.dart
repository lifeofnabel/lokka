import 'package:flutter/material.dart';

class FeedDealCard extends StatelessWidget {
  const FeedDealCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

