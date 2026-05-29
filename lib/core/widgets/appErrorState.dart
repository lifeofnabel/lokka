import 'package:flutter/material.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

