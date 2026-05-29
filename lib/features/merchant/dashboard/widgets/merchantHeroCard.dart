import 'package:flutter/material.dart';

class MerchantHeroCard extends StatelessWidget {
  const MerchantHeroCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

