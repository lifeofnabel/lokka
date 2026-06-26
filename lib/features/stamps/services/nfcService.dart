import 'nfcServiceStub.dart'
    if (dart.library.js_interop) 'nfcServiceWeb.dart' as impl;

/// Web NFC gateway. A real implementation exists only on Flutter Web where the
/// browser exposes `NDEFReader` (Android Chrome). Every other platform/browser
/// — iOS Safari, desktop, non-web builds — reports [isSupported] = false and the
/// UI falls back to Path B (pre-provisioned QR-bound sticks).
abstract class NfcService {
  /// Whether the runtime exposes Web NFC. Drives Path A vs Path B selection.
  bool get isSupported;

  /// Writes a single URL NDEF record onto the next tapped tag. Resolves on a
  /// successful write; throws [NfcError] on permission denial, abort, removed
  /// tag, or hardware failure.
  Future<void> writeUrl(String url);

  /// Reads the first URL found on the next tapped tag (used by the Test-Tap),
  /// or null on timeout. Throws [NfcError] on permission denial.
  Future<String?> readUrl({Duration timeout = const Duration(seconds: 25)});
}

enum NfcErrorKind { unsupported, permissionDenied, aborted, notFound, failed }

class NfcError implements Exception {
  const NfcError(this.kind, [this.message = '']);
  final NfcErrorKind kind;
  final String message;

  /// Translatable i18n key for a user-facing message.
  String get textKey => switch (kind) {
        NfcErrorKind.unsupported => 'merchant.stick.nfc.errUnsupported',
        NfcErrorKind.permissionDenied => 'merchant.stick.nfc.errPermission',
        NfcErrorKind.aborted => 'merchant.stick.nfc.errAborted',
        NfcErrorKind.notFound => 'merchant.stick.nfc.errNotFound',
        NfcErrorKind.failed => 'merchant.stick.nfc.errFailed',
      };

  @override
  String toString() => 'NfcError($kind, $message)';
}

/// Factory — returns the web implementation on Flutter Web, otherwise a stub.
NfcService createNfcService() => impl.createNfcService();
