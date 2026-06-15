import 'package:flutter/material.dart';


class AppShadows {
  const AppShadows._();

  static const soft = [
    BoxShadow(
      color: Color(0x1F1A6F5E),
      blurRadius: 30,
      offset: Offset(0, 18),
    ),
  ];

  static const card = [
    BoxShadow(
      color: Color(0x17171A18),
      blurRadius: 36,
      offset: Offset(0, 18),
    ),
  ];
}
