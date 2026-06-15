import 'dart:convert';

import '../cache/localCacheStorage.dart';

class LocalCacheService {
  LocalCacheService({this.defaultTtl = const Duration(hours: 24)});

  final Duration defaultTtl;
  final Map<String, _CacheEntry> _memory = {};

  Future<Map<String, dynamic>?> readMap(
    String key, {
    Duration? ttl,
  }) async {
    final value = await _readPayload(key, ttl ?? defaultTtl);
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  Future<List<Map<String, dynamic>>?> readMapList(
    String key, {
    Duration? ttl,
  }) async {
    final value = await _readPayload(key, ttl ?? defaultTtl);
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return null;
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) {
    return _writePayload(key, value);
  }

  Future<void> writeMapList(String key, List<Map<String, dynamic>> value) {
    return _writePayload(key, value);
  }

  Future<DateTime?> readTimestamp(String key, {Duration? ttl}) async {
    final map = await readMap(key, ttl: ttl);
    final value = map?['value'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  Future<void> writeTimestamp(String key, DateTime value) {
    return writeMap(key, {'value': value.toIso8601String()});
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
    await LocalCacheStorage.remove(_storageKey(key));
  }

  Future<dynamic> _readPayload(String key, Duration ttl) async {
    final memory = _memory[key];
    if (memory != null && !_isExpired(memory.savedAt, ttl)) {
      return memory.value;
    }

    final raw = await LocalCacheStorage.read(_storageKey(key));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(decoded['savedAt'].toString());
      if (savedAt == null || _isExpired(savedAt, ttl)) {
        await remove(key);
        return null;
      }
      final value = decoded['value'];
      _memory[key] = _CacheEntry(value: value, savedAt: savedAt);
      return value;
    } catch (_) {
      await remove(key);
      return null;
    }
  }

  Future<void> _writePayload(String key, dynamic value) async {
    final savedAt = DateTime.now();
    _memory[key] = _CacheEntry(value: value, savedAt: savedAt);
    await LocalCacheStorage.write(
      _storageKey(key),
      jsonEncode({
        'savedAt': savedAt.toIso8601String(),
        'value': value,
      }),
    );
  }

  bool _isExpired(DateTime savedAt, Duration ttl) {
    return DateTime.now().difference(savedAt) > ttl;
  }

  String _storageKey(String key) => 'lokka.cache.$key';
}

class _CacheEntry {
  const _CacheEntry({
    required this.value,
    required this.savedAt,
  });

  final dynamic value;
  final DateTime savedAt;
}
