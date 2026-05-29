import 'package:flutter/material.dart';

class MerchantProfileForm extends StatelessWidget {
  const MerchantProfileForm({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

