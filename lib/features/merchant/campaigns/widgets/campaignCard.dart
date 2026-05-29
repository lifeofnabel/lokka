import 'package:flutter/material.dart';

class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

