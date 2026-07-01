import 'package:flutter/foundation.dart';

/// Welcher User-Tab gerade sichtbar ist (0 = Feed, 1 = Suche, 2 = Wallet,
/// 3 = Profil). Global, weil [DeferredWarmup] providerübergreifend prüfen
/// muss, ohne dass jeder Provider seinen Konsumenten-Baum kennt.
class TabPriority {
  TabPriority._();

  static final ValueNotifier<int> activeIndex = ValueNotifier<int>(0);
}

/// Verzögert einen Ladevorgang, der zu einem nicht-aktiven Tab gehört, statt
/// ihn sofort gegen den aktiven Tab um dieselbe Firestore-Verbindung
/// konkurrieren zu lassen. Echtes Abbrechen ist mit dem Firestore-Dart-SDK
/// nicht möglich – stattdessen bekommt der gerade sichtbare Tab Vorrang, ein
/// verlassener Tab lädt mit wachsendem Backoff nach (max. 3 Versuche, danach
/// läuft er ungebremst, damit er beim nächsten Wechsel dorthin schon warm ist).
class DeferredWarmup {
  DeferredWarmup._();

  static const _backoffStep = Duration(milliseconds: 250);
  static const _maxAttempts = 3;

  static void schedule(int tabIndex, VoidCallback task) {
    _attempt(tabIndex, task, 0);
  }

  static void _attempt(int tabIndex, VoidCallback task, int attempt) {
    if (TabPriority.activeIndex.value == tabIndex || attempt >= _maxAttempts) {
      task();
      return;
    }
    Future.delayed(_backoffStep * (attempt + 1), () {
      _attempt(tabIndex, task, attempt + 1);
    });
  }
}
