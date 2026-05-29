import 'package:flutter/animation.dart';

class AppAnimations {
  const AppAnimations._();

  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutQuart;
}
