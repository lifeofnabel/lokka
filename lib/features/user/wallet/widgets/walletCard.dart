import 'package:flutter/material.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

