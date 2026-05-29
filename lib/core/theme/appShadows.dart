import 'package:flutter/material.dart';

import 'appColors.dart';

class AppShadows {
  const AppShadows._();

  static const soft = [
    BoxShadow(
      color: AppColors.gray100,
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}
