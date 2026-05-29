import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child ?? const Text('Keine Inhalte vorhanden.'));
  }
}

