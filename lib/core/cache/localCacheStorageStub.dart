final Map<String, String> _memoryStorage = {};

Future<String?> readCacheValue(String key) async {
  return _memoryStorage[key];
}

Future<void> writeCacheValue(String key, String value) async {
  _memoryStorage[key] = value;
}

Future<void> removeCacheValue(String key) async {
  _memoryStorage.remove(key);
}
