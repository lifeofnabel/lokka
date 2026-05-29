import 'package:flutter/material.dart';

class TableCard extends StatelessWidget {
  const TableCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

