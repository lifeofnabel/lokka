import 'dart:convert';
import 'package:flutter/services.dart';

class PostalCodeEntry {
  const PostalCodeEntry({
    required this.postalCode,
    required this.placeName,
    required this.adminName1,
    required this.lat,
    required this.lng,
  });

  final String postalCode;
  final String placeName;
  final String adminName1;
  final double lat;
  final double lng;

  factory PostalCodeEntry.fromMap(Map<String, dynamic> map) {
    return PostalCodeEntry(
      postalCode: map['postalCode'] as String? ?? '',
      placeName: map['placeName'] as String? ?? '',
      adminName1: map['adminName1'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() => '$postalCode $placeName';
}

class PostalCodeService {
  PostalCodeService();

  List<PostalCodeEntry> _entries = [];
  bool _loaded = false;

  Future<void> loadAll() async {
    if (_loaded) return;
    final raw = await rootBundle
        .loadString('assets/data/frankfurtPostalCodes.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _entries = list
        .map((e) => PostalCodeEntry.fromMap(e as Map<String, dynamic>))
        .toList();
    _loaded = true;
  }

  PostalCodeEntry? findByPostalCode(String code) {
    final trimmed = code.trim();
    try {
      return _entries.firstWhere((e) => e.postalCode == trimmed);
    } catch (_) {
      return null;
    }
  }

  List<PostalCodeEntry> suggestions(String input, {int max = 5}) {
    final trimmed = input.trim();
    if (trimmed.length < 2) return [];
    return _entries
        .where((e) =>
            e.postalCode.startsWith(trimmed) ||
            e.placeName.toLowerCase().contains(trimmed.toLowerCase()))
        .take(max)
        .toList();
  }

  bool isValidPostalCode(String code) => findByPostalCode(code) != null;
}
