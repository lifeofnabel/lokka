import 'package:flutter/material.dart';

class ShopSettingsTile extends StatelessWidget {
  const ShopSettingsTile({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

