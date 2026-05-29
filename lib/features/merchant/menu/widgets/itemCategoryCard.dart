import 'package:flutter/material.dart';

class ItemCategoryCard extends StatelessWidget {
  const ItemCategoryCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

