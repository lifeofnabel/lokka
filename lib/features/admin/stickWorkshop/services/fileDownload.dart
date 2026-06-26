import 'fileDownloadStub.dart'
    if (dart.library.js_interop) 'fileDownloadWeb.dart' as impl;

/// Triggers a client-side file download. Real only on Flutter Web (the Godmode
/// panel runs in the browser); other platforms report [downloadSupported] =
/// false and [downloadBytes] throws.
bool get downloadSupported => impl.downloadSupported;

void downloadBytes(List<int> bytes, String filename, String mime) =>
    impl.downloadBytes(bytes, filename, mime);
