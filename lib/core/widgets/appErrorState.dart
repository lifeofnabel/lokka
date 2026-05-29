import 'package:flutter/material.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child ?? const Text('Ein Fehler ist aufgetreten.'));
  }
}

