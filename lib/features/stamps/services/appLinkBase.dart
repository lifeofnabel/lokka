import 'appLinkBaseStub.dart'
    if (dart.library.js_interop) 'appLinkBaseWeb.dart' as impl;

/// Absolute base URL the web app is served from — the document's `<base href>`,
/// e.g. `https://jajehelp.com/lokka/`. Empty on non-web builds.
///
/// Used to build share links that respect both the deployed sub-path (`/lokka/`)
/// and the path-URL strategy (routes have no `#`). The tap link for a stick is
/// therefore `<appLinkBase()>s/<token>` → `https://jajehelp.com/lokka/s/<token>`.
String appLinkBase() => impl.appLinkBase();
