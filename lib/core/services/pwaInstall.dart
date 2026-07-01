import 'pwaInstallStub.dart' if (dart.library.js_interop) 'pwaInstallWeb.dart'
    as impl;

/// Whether the browser has offered a native install prompt for this session.
bool get pwaInstallAvailable => impl.pwaInstallAvailable;

/// Triggers the native install prompt. Returns 'accepted', 'dismissed', or
/// 'unavailable' when no prompt was captured (caller should show manual
/// "Add to Home Screen" instructions instead).
Future<String> promptPwaInstall() => impl.promptPwaInstall();
