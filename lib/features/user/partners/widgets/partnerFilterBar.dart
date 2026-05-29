import 'package:flutter/material.dart';

class PartnerFilterBar extends StatelessWidget {
  const PartnerFilterBar({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

