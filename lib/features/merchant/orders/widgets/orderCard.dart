import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

