import 'package:flutter/material.dart';

class MerchantFeedPostCard extends StatelessWidget {
  const MerchantFeedPostCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

