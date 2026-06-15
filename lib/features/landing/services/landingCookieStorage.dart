import 'landingCookieStorageStub.dart'
    if (dart.library.html) 'landingCookieStorageWeb.dart' as platform;

class LandingCookieStorage {
  const LandingCookieStorage._();

  static Future<bool> hasChoice() {
    return platform.hasCookieChoice();
  }

  static Future<void> saveChoice(String choice) {
    return platform.saveCookieChoice(choice);
  }
}
