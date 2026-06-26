import 'nfcService.dart';

/// Non-web (and non-NFC) fallback: Web NFC does not exist here. Reports
/// unsupported so the UI offers Path B (pre-provisioned sticks) instead.
NfcService createNfcService() => const _UnsupportedNfc();

class _UnsupportedNfc implements NfcService {
  const _UnsupportedNfc();

  @override
  bool get isSupported => false;

  @override
  Future<void> writeUrl(String url) async =>
      throw const NfcError(NfcErrorKind.unsupported);

  @override
  Future<String?> readUrl({Duration timeout = const Duration(seconds: 25)}) async =>
      throw const NfcError(NfcErrorKind.unsupported);
}
