import 'package:flutter/material.dart';

class LandingHeroCard extends StatelessWidget {
  const LandingHeroCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

