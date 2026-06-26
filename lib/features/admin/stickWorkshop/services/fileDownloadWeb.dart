// Web-only download via a data-URL anchor. Same dart:js_interop approach as the
// project's NFC web service (no extra package:web dependency).
// ignore_for_file: invalid_runtime_check_with_js_interop_types
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool get downloadSupported => true;

void downloadBytes(List<int> bytes, String filename, String mime) {
  final doc = globalContext.getProperty('document'.toJS) as JSObject;
  final anchor = doc.callMethod('createElement'.toJS, 'a'.toJS) as JSObject;
  final b64 = base64Encode(bytes);
  anchor.setProperty('href'.toJS, 'data:$mime;base64,$b64'.toJS);
  anchor.setProperty('download'.toJS, filename.toJS);
  anchor.callMethod('click'.toJS);
}
