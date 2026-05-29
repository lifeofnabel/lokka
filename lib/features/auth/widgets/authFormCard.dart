import 'package:flutter/material.dart';

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

