import 'package:flutter/material.dart';

class UserQrCard extends StatelessWidget {
  const UserQrCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

