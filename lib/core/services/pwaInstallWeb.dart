// Web-only: trigger the browser's native "Add to Home Screen" / install
// prompt via the `beforeinstallprompt` event stashed by web/index.html. Same
// dart:js_interop approach as the project's other web-only services (no
// package:web dependency).
// ignore_for_file: invalid_runtime_check_with_js_interop_types
import 'dart:js_interop';

@JS('__lokkaInstallAvailable')
external bool _installAvailable();

@JS('__lokkaPromptInstall')
external JSPromise<JSString> _promptInstall();

/// True once the browser has fired `beforeinstallprompt` (Chrome/Edge/Android
/// Chrome). False on Safari/iOS and browsers with no install prompt support.
bool get pwaInstallAvailable {
  try {
    return _installAvailable();
  } catch (_) {
    return false;
  }
}

/// Shows the native install prompt and returns 'accepted', 'dismissed', or
/// 'unavailable' (no captured prompt — caller should fall back to manual
/// "Add to Home Screen" instructions).
Future<String> promptPwaInstall() async {
  try {
    final result = await _promptInstall().toDart;
    return result.toDart;
  } catch (_) {
    return 'unavailable';
  }
}
