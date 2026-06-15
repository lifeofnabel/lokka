import 'localCacheStorageStub.dart'
    if (dart.library.html) 'localCacheStorageWeb.dart' as platform;

class LocalCacheStorage {
  const LocalCacheStorage._();

  static Future<String?> read(String key) {
    return platform.readCacheValue(key);
  }

  static Future<void> write(String key, String value) {
    return platform.writeCacheValue(key, value);
  }

  static Future<void> remove(String key) {
    return platform.removeCacheValue(key);
  }
}
