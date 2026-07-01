/// Non-web fallback — there is no browser install prompt off the web.
bool get pwaInstallAvailable => false;

Future<String> promptPwaInstall() async => 'unavailable';
