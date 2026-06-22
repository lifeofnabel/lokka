// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web-Implementierung des Neu-Bestellung-Alarms (gleiches dart:html-Muster
/// wie die übrigen Web-Plattformdateien des Projekts).

bool _primed = false;
double _volume = 0.5;

/// Kurzer 880-Hz-Sinus-Beep (0,18 s, 8-bit/8 kHz Mono-WAV) als Data-URI –
/// braucht kein Audio-Asset und wird über ein <audio>-Element abgespielt.
const String _beepDataUri =
    'data:audio/wav;base64,UklGRsQFAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YaAFAACAgIGBgX9+fX6Ag4WFgn57eXt/hIiJhX54dXd+hoyNh351cXR8h4+Rin9zbXB6h5KVjoByamx3h5WZkYJwZmd0h5edloRwY2NxhpmhmoZvYF5thZulnolwXVppg5ypo41wW1ZkgJysqJFyWVFffZyvrZV0V01aeZyyspp2VklVdpu1tp95VUVQcZq3u6R8VUJKbJi5wKqAVj5FZ5W6xbCEVzs/YZK7ybaJWDk6XI67zLuOWzk4V4q4zL6TYDs2U4W0zMCYZD01T4Cxy8OcaEA0THutysWgbUI0SHapyMelckU0RXKlx8ipdkg0Qm2gxcqte0w0QGicw8uxgE81PWSYwMy0hVM2O2CTvsy4ilc4OVuOu8y7jls5OFeKuMy+k2A7NlOFtMzAmGQ9NU+AscvDnGhANEx7rcrFoG1CNEh2qcjHpXJFNEVypcfIqXZINEJtoMXKrXtMNEBonMPLsYBPNT1kmMDMtIVTNjtgk77MuIpXODlbjrvMu45bOThXirjMvpNgOzZThbTMwJhkPTVPgLHLw5xoQDRMe63KxaBtQjRIdqnIx6VyRTRFcqXHyKl2SDRCbaDFyq17TDRAaJzDy7GATzU9ZJjAzLSFUzY7YJO+zLiKVzg5W467zLuOWzk4V4q4zL6TYDs2U4W0zMCYZD01T4Cxy8OcaEA0THutysWgbUI0SHapyMelckU0RXKlx8ipdkg0Qm2gxcqte0w0QGicw8uxgE81PWSYwMy0hVM2O2CTvsy4ilc4OVuOu8y7jls5OFeKuMy+k2A7NlOFtMzAmGQ9NU+AscvDnGhANEx7rcrFoG1CNEh2qcjHpXJFNEVypcfIqXZINEJtoMXKrXtMNEBonMPLsYBPNT1kmMDMtIVTNjtgk77MuIpXODlbjrvMu45bOThXirjMvpNgOzZThbTMwJhkPTVPgLHLw5xoQDRMe63KxaBtQjRIdqnIx6VyRTRFcqXHyKl2SDRCbaDFyq17TDRAaJzDy7GATzU9ZJjAzLSFUzY7YJO+zLiKVzg5W467zLuOWzk4V4q4zL6TYDs2U4W0zMCYZD01T4Cxy8OcaEA0THutysWgbUI0SHapyMelckU0RXKlx8ipdkg0Qm2gxcqte0w0QGicw8uxgE81PWSYwMy0hVM2O2CTvsy4ilc4OVuOu8y7jls5OFeKuMy+k2A7NlOFtMzAmGQ9NU+AscvDnGhANEx7rcrFoG1CNEh2qcjHpXJFNEVypcfIqXZINEJtoMXKrXtMNEBonMPLsYBPNT1kmMDMtIVTNjtgk77MuIpXODlbjrvMu45bOThXirjMvpNgOzZThbTMwJhkPTVPgLHLw5xoQDRMe63KxaBtQjRIdqnIx6VyRTRFcqXHyKl2SDRCbaDFyq17TDRAaJzDy7GATzU9ZJjAzLSFUzY7YJO+zLiKVzg5W467zLuOWzk4V4q4zL6TYDs2U4W0zMCYZD01T4Cxy8OcaEA0THutysWgbUI0SHapyMelckU0RXKlx8ipdkg0Qm2gxcqte0w0QGicw8uxgE81PWSYwMy0hVM2O2CTvsy4ilY4O1yOuMm4jV4+PVqJssW3kWNDQFmErcC2lGlJQ1iAp7y1lm5ORlh8orezmHJTSVl5nbKxmXZZTVl3mK2umnpeUVt1k6mrmn1iVlxzj6SomoBnWl5yjJ+kmYJrXmFyiJuhl4RvY2RyhpadloVzZ2dyg5KZlIZ2a2pzgY6VkYZ5b250gIuQjoZ7c3J2f4iMi4V9d3V5f4WIiIR/e3l7f4OFhIKAfn1+gIGBgA==';

void prime() {
  if (_primed) return;
  _primed = true;
  ensurePermission();
}

void ensurePermission() {
  try {
    if (html.Notification.supported &&
        html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  } catch (_) {/* Benachrichtigungen nicht verfügbar – ignorieren */}
}

bool isPageHidden() {
  try {
    return html.document.hidden ?? false;
  } catch (_) {
    return false;
  }
}

void setVolume(double v) => _volume = v.clamp(0.0, 1.0);

void playTone() {
  // <audio>-Element mit eingebettetem Beep – kein WebAudio nötig (in neueren
  // SDKs ist dart:web_audio entfernt).
  try {
    html.AudioElement(_beepDataUri)
      ..volume = _volume
      ..play();
  } catch (_) {/* Audio gesperrt (noch keine Geste) – ignorieren */}
}

void showNotification(String title, String body) {
  try {
    if (html.Notification.supported &&
        html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (_) {/* Benachrichtigung fehlgeschlagen – ignorieren */}
}
