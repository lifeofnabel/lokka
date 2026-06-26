// Web-only NFC-Implementierung – JS-Interop-Runtime-Check ist hier bewusst.
// ignore_for_file: invalid_runtime_check_with_js_interop_types
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'nfcService.dart';

/// Flutter Web implementation of [NfcService] using the Web NFC API
/// (`NDEFReader`). Only Android Chrome exposes it; elsewhere [isSupported] is
/// false and the UI uses Path B.
NfcService createNfcService() => _WebNfc();

@JS('NDEFReader')
@staticInterop
class _NDEFReader {
  external factory _NDEFReader();
}

extension _NDEFReaderExt on _NDEFReader {
  external JSPromise<JSAny?> write(JSAny message);
  external JSPromise<JSAny?> scan(JSAny options);
  external set onreading(JSFunction value);
  external set onreadingerror(JSFunction value);
}

@JS('TextDecoder')
@staticInterop
class _TextDecoder {
  external factory _TextDecoder();
}

extension _TextDecoderExt on _TextDecoder {
  external JSString decode(JSAny input);
}

@JS('AbortController')
@staticInterop
class _AbortController {
  external factory _AbortController();
}

extension _AbortControllerExt on _AbortController {
  external JSAny get signal;
  external void abort();
}

class _WebNfc implements NfcService {
  @override
  bool get isSupported {
    try {
      return globalContext.has('NDEFReader');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> writeUrl(String url) async {
    if (!isSupported) throw const NfcError(NfcErrorKind.unsupported);
    try {
      final reader = _NDEFReader();
      final message = <String, Object?>{
        'records': [
          <String, Object?>{'recordType': 'url', 'data': url},
        ],
      }.jsify()!;
      await reader.write(message).toDart;
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<String?> readUrl(
      {Duration timeout = const Duration(seconds: 25)}) async {
    if (!isSupported) throw const NfcError(NfcErrorKind.unsupported);
    final reader = _NDEFReader();
    final completer = Completer<String?>();
    final controller = _AbortController();

    reader.onreading = (JSAny event) {
      if (completer.isCompleted) return;
      completer.complete(_extractUrl(event));
    }.toJS;
    reader.onreadingerror = (JSAny _) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;

    try {
      final options = JSObject();
      options.setProperty('signal'.toJS, controller.signal);
      await reader.scan(options).toDart;
    } catch (e) {
      throw _map(e);
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      try {
        controller.abort();
      } catch (_) {}
    }
  }

  /// Walks `event.message.records`, decodes each record's bytes and returns the
  /// first string that looks like an http(s) URL. Defensive — any shape error
  /// yields null (treated as a read failure → retry).
  String? _extractUrl(JSAny event) {
    try {
      final message = (event as JSObject).getProperty('message'.toJS);
      if (message == null) return null;
      final records = (message as JSObject).getProperty('records'.toJS);
      if (records == null) return null;
      final list = (records as JSArray).toDart;
      final decoder = _TextDecoder();
      for (final item in list) {
        if (item == null) continue;
        final data = (item as JSObject).getProperty('data'.toJS);
        if (data == null) continue;
        String text;
        try {
          text = decoder.decode(data).toDart;
        } catch (_) {
          continue;
        }
        final match = RegExp(r'https?://[^\s]+').firstMatch(text);
        if (match != null) return match.group(0);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  NfcError _map(Object e) {
    final name = _errorName(e).toLowerCase();
    if (name.contains('notallowed') || name.contains('security')) {
      return const NfcError(NfcErrorKind.permissionDenied);
    }
    if (name.contains('abort')) return const NfcError(NfcErrorKind.aborted);
    if (name.contains('notsupported')) {
      return const NfcError(NfcErrorKind.unsupported);
    }
    if (name.contains('notfound') || name.contains('notreadable')) {
      return const NfcError(NfcErrorKind.notFound);
    }
    return NfcError(NfcErrorKind.failed, name);
  }

  String _errorName(Object e) {
    try {
      if (e is JSObject) {
        final n = e.getProperty('name'.toJS);
        if (n != null) return (n as JSString).toDart;
      }
    } catch (_) {}
    return e.toString();
  }
}
