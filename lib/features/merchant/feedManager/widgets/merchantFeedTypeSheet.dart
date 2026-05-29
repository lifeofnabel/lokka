import 'package:flutter/material.dart';

class MerchantFeedTypeSheet extends StatelessWidget {
  const MerchantFeedTypeSheet({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

