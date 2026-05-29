class ScannerService {
  const ScannerService();

  Future<void> initialize() async {}

  bool canHandlePayload(String payload) {
    return payload.startsWith('lokka://');
  }
}
