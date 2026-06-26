// Web-only: read the document's <base href> via JS interop.
// ignore_for_file: invalid_runtime_check_with_js_interop_types
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('document')
external JSObject get _document;

/// Returns `document.baseURI` (absolute, e.g. `https://host/lokka/`), or '' on
/// any failure so callers can fall back to `Uri.base`.
String appLinkBase() {
  try {
    final v = _document.getProperty<JSString?>('baseURI'.toJS);
    return v?.toDart ?? '';
  } catch (_) {
    return '';
  }
}
