import 'package:flutter/material.dart';

class PartnerHeroCard extends StatelessWidget {
  const PartnerHeroCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

