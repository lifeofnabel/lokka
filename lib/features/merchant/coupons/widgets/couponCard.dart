import 'package:flutter/material.dart';

class CouponCard extends StatelessWidget {
  const CouponCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

