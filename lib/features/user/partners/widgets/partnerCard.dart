import 'package:flutter/material.dart';

class PartnerCard extends StatelessWidget {
  const PartnerCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

