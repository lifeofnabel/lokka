import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/firestoreService.dart';

import '../models/userMenuModels.dart';

/// Liest die in Lokka integrierte Speisekarte eines Partners (read-only).
///
/// Quelle ist der bestehende Merchant-Katalog
/// (`merchants/{id}/itemCategories` + `merchants/{id}/items`).
/// Es wird die komplette (kleine) Subcollection geladen und client-seitig
/// gefiltert/gruppiert — so sind keine Firestore-Composite-Indizes nötig.
class UserMenuService {
  UserMenuService({required FirestoreService firestoreService})
      : _firestore = firestoreService;

  final FirestoreService _firestore;

  Future<List<UserMenuCategory>> fetchMenu(String merchantId) async {
    final catSnap = await _firestore
        .collection(FirebasePaths.merchantItemCategories(merchantId))
        .get();
    final itemSnap = await _firestore
        .collection(FirebasePaths.merchantItems(merchantId))
        .get();

    // Nur öffentliche, aktive Kategorien.
    final categories = catSnap.docs
        .map((doc) => {...doc.data(), 'id': doc.data()['id'] ?? doc.id})
        .where((map) =>
            (map['isActive'] as bool? ?? true) &&
            !(map['isPrivate'] as bool? ?? false))
        .map(UserMenuCategory.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Nur öffentliche, aktive, verfügbare Einträge.
    final items = itemSnap.docs
        .map((doc) => {...doc.data(), 'id': doc.data()['id'] ?? doc.id})
        .where((map) =>
            (map['isActive'] as bool? ?? true) &&
            !(map['isPrivate'] as bool? ?? false))
        .map(UserMenuItem.fromMap)
        .where((item) => item.isAvailable)
        .toList();

    // Einträge ihren Kategorien zuordnen.
    final byCategory = <String, List<UserMenuItem>>{};
    for (final item in items) {
      byCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    final result = <UserMenuCategory>[];
    for (final category in categories) {
      final catItems = byCategory.remove(category.id) ?? const [];
      if (catItems.isEmpty) continue; // leere Kategorien überspringen
      result.add(category.copyWith(items: catItems));
    }

    // Einträge ohne passende (öffentliche) Kategorie sammeln.
    final orphans = byCategory.values.expand((list) => list).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (orphans.isNotEmpty) {
      result.add(UserMenuCategory(
        id: '_weitere',
        name: 'Weitere',
        sortOrder: 9999,
        items: orphans,
      ));
    }

    return result;
  }
}
