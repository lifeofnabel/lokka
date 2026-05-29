import 'package:flutter/material.dart';

class CampaignEntryCard extends StatelessWidget {
  const CampaignEntryCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

