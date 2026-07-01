import 'package:flutter/animation.dart';

/// Shared motion tokens. A stronger, more deliberate ease-out than the stock
/// Curves.easeOut — used for anything entering the screen (cards, sheets,
/// staggered lists) so entrances feel snappy instead of soft.
class AppMotion {
  const AppMotion._();

  static const strongEaseOut = Cubic(0.23, 1, 0.32, 1);

  /// Press/tap feedback (button scale-down).
  static const fast = Duration(milliseconds: 140);

  /// Single-element entrance (fade/rise).
  static const entrance = Duration(milliseconds: 320);

  /// Gap between staggered siblings entering together.
  static const staggerStep = 0.12;
}
