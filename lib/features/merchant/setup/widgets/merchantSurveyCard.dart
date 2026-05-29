import 'package:flutter/material.dart';

class MerchantSurveyCard extends StatelessWidget {
  const MerchantSurveyCard({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

