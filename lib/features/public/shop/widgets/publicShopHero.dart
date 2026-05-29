import 'package:flutter/material.dart';

class PublicShopHero extends StatelessWidget {
  const PublicShopHero({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

