/// Non-web fallback — the Godmode panel is web-only.
bool get downloadSupported => false;

void downloadBytes(List<int> bytes, String filename, String mime) {
  throw UnsupportedError('Download ist nur im Web verfügbar.');
}
