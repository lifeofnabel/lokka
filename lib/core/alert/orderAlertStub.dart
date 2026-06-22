import 'package:flutter/services.dart';

/// Nicht-Web-Implementierung (Mobile/Desktop/Tests).
///
/// Browser-spezifische Funktionen (Benachrichtigung, Tab-Sichtbarkeit,
/// Autoplay-Freischaltung) sind hier No-Ops; der Hinweiston nutzt den
/// plattformeigenen System-Alarmton (ohne zusätzliche Abhängigkeit).

void prime() {}

void ensurePermission() {}

bool isPageHidden() => false;

void playTone() {
  // Plattformeigener Alarmton – graceful, falls die Plattform ihn nicht kennt.
  SystemSound.play(SystemSoundType.alert);
}

void showNotification(String title, String body) {}
