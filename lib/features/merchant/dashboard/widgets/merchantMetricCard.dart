import 'package:flutter/material.dart';

class MerchantMetricCard extends StatelessWidget {
  const MerchantMetricCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

