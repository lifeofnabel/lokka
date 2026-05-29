import 'package:flutter/material.dart';

class PublicShopActionBar extends StatelessWidget {
  const PublicShopActionBar({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

