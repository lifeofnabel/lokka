import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/appConfig.dart';
import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/geoapifyService.dart';
import '../../catalog/data/voilaSeedData.dart';
import '../../catalog/models/itemCategoryData.dart';
import '../../catalog/models/itemOptionGroup.dart';
import '../../catalog/models/itemTagData.dart';
import '../../catalog/models/merchantItemData.dart';
import '../../catalog/models/runnerData.dart';
import '../../tables/models/merchantTableData.dart';

export '../../catalog/models/itemCategoryData.dart';
export '../../catalog/models/itemOptionGroup.dart';
export '../../catalog/models/itemTagData.dart';
export '../../catalog/models/merchantItemData.dart';
export '../../catalog/models/runnerData.dart';
export '../../tables/models/merchantTableData.dart';

class MerchantToolsService {
  const MerchantToolsService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw StateError('auth.error.signInAgain');
    }
    return uid;
  }

  Future<Map<String, dynamic>?> loadMerchant() {
    return firestoreService.getMerchantProfile(merchantId);
  }

  /// Runner (Name + PIN) liegen als Liste im publicMerchants-Doc, damit das
  /// Bestell-Gerät im Shop sie zum PIN-Login lesen kann.
  Future<List<RunnerData>> loadRunners() async {
    final data = await firestoreService.readDocument(
      FirebasePaths.publicMerchant(merchantId),
    );
    return RunnerData.listFromRaw(data?['runners']);
  }

  Future<void> saveRunners(List<RunnerData> runners) {
    return firestoreService.setDocument(
      FirebasePaths.publicMerchant(merchantId),
      {
        'runners': runners.map((runner) => runner.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Speichert die öffentliche Speisekarte-URL des Merchants im publicMerchants-
  /// Doc (damit sie automatisch hinterlegt/abrufbar ist). Merge = überschreibt
  /// nichts anderes.
  Future<void> saveShopUrl(String url) {
    return firestoreService.setDocument(
      FirebasePaths.publicMerchant(merchantId),
      {'shopUrl': url, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<List<String>> loadChooserShopTypes() {
    return firestoreService.loadChooserShopTypes();
  }

  Future<List<String>> loadChooserAreas() {
    return firestoreService.loadChooserAreas();
  }

  Future<List<ItemCategoryData>> loadCategories() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItemCategories(merchantId))
        .limit(200) // unbeschränkte Reads vermeiden (#88)
        .get();
    final categories = snapshot.docs
        .map((doc) => ItemCategoryData.fromMap({'id': doc.id, ...doc.data()}))
        .where((category) => !category.isArchived)
        .toList();
    categories.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return categories;
  }

  Future<void> saveCategory({
    String? id,
    required String name,
    required String emoji,
    required String iconUrl,
    required int sortOrder,
    required bool isActive,
    required bool isPrivate,
  }) async {
    final categoryId = id?.isNotEmpty == true
        ? id!
        : firestoreService.collection(FirebasePaths.merchantItemCategories(merchantId)).doc().id;
    final isNew = id == null || id.isEmpty;
    await firestoreService.setDocument(
      FirebasePaths.merchantItemCategory(merchantId, categoryId),
      {
        'id': categoryId,
        'merchantId': merchantId,
        'name': name.trim(),
        'normalizedName': _normalize(name),
        'sortOrder': sortOrder,
        'emoji': emoji.trim(),
        'iconUrl': iconUrl.trim(),
        'isActive': isActive,
        'isPrivate': isPrivate,
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<bool> categoryHasItems(String categoryId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItems(merchantId))
        .where('categoryId', isEqualTo: categoryId)
        .limit(20)
        .get();
    return snapshot.docs.any((doc) => doc.data()['isArchived'] != true);
  }

  Future<void> deleteCategory(String categoryId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantItemCategory(merchantId, categoryId),
      {
        'isActive': false,
        'isPrivate': true,
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<List<MerchantItemData>> loadItems() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItems(merchantId))
        .limit(500) // unbeschränkte Reads vermeiden (#88)
        .get();
    final items = snapshot.docs
        .map((doc) => MerchantItemData.fromMap({'id': doc.id, ...doc.data()}))
        .where((item) => !item.isArchived)
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<List<ItemTagData>> loadItemTags() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItemTags(merchantId))
        .limit(200) // unbeschränkte Reads vermeiden (#88)
        .get();
    final customTags = snapshot.docs
        .map((doc) => ItemTagData.fromMap({'id': doc.id, ...doc.data()}))
        .where((tag) => tag.isActive)
        .toList();
    final tags = [
      ...defaultItemTags(merchantId),
      ...customTags,
    ];
    tags.sort((a, b) {
      final type = a.type.compareTo(b.type);
      if (type != 0) return type;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return tags;
  }

  Future<void> saveItemTag({
    String? id,
    required String type,
    required String code,
    required String name,
  }) async {
    final tagId = id?.isNotEmpty == true
        ? id!
        : firestoreService.collection(FirebasePaths.merchantItemTags(merchantId)).doc().id;
    final isNew = id == null || id.isEmpty;
    await firestoreService.setDocument(
      FirebasePaths.merchantItemTag(merchantId, tagId),
      {
        'id': tagId,
        'merchantId': merchantId,
        'type': type,
        'code': code.trim(),
        'name': name.trim(),
        'isActive': true,
        'isCustom': true,
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteItemTag(String tagId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantItemTag(merchantId, tagId),
      {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> saveItem({
    String? id,
    required String categoryId,
    required String categoryName,
    required String name,
    required String description,
    required num price,
    required num? originalPrice,
    required String imageUrl,
    required String articleNumber,
    required List<String> allergenIds,
    required List<String> additiveIds,
    required bool isActive,
    required bool isAvailable,
    required bool isPrivate,
    String imageRatio = 'square',
    List<ItemOptionGroup> optionGroups = const [],
  }) async {
    final itemId = id?.isNotEmpty == true
        ? id!
        : firestoreService.collection(FirebasePaths.merchantItems(merchantId)).doc().id;
    final isNew = id == null || id.isEmpty;
    await firestoreService.setDocument(
      FirebasePaths.merchantItem(merchantId, itemId),
      {
        'id': itemId,
        'merchantId': merchantId,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'name': name.trim(),
        'title': name.trim(),
        'description': description.trim(),
        'price': price,
        'originalPrice': originalPrice,
        'imageUrl': imageUrl.trim(),
        'articleNumber': articleNumber.trim(),
        'allergenIds': allergenIds,
        'additiveIds': additiveIds,
        'isActive': isActive,
        'isAvailable': isAvailable,
        'isPrivate': isPrivate,
        'imageRatio': imageRatio,
        'optionGroups': optionGroups.map((group) => group.toMap()).toList(),
        'type': 'merchant_item',
        'searchName': _normalize(name),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteItem(String itemId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantItem(merchantId, itemId),
      {
        'isActive': false,
        'isPrivate': true,
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Löscht ALLE vorhandenen Artikel + Kategorien (hard delete) und legt die
  /// 193 Voilà-Standardartikel in 17 Kategorien neu an.
  Future<void> seedCatalog() async {
    // 1. Alle vorhandenen Docs laden (inkl. archivierte).
    final existingItemsSnap = await firestoreService
        .collection(FirebasePaths.merchantItems(merchantId))
        .limit(500)
        .get();
    final existingCatsSnap = await firestoreService
        .collection(FirebasePaths.merchantItemCategories(merchantId))
        .limit(200)
        .get();

    // 2. Hard-Delete in Batches à 490 (Firestore-Limit = 500).
    final allDocs = [...existingItemsSnap.docs, ...existingCatsSnap.docs];
    for (var i = 0; i < allDocs.length; i += 490) {
      final end = (i + 490 < allDocs.length) ? i + 490 : allDocs.length;
      final batch = firestoreService.batch();
      for (final doc in allDocs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // 3. 17 Kategorien anlegen (ein Batch reicht).
    {
      final batch = firestoreService.batch();
      for (final cat in kVoilaCategories) {
        final catId = cat['id'] as String;
        final ref = firestoreService.document(
          FirebasePaths.merchantItemCategory(merchantId, catId),
        );
        batch.set(ref, {
          'id': catId,
          'merchantId': merchantId,
          'name': cat['name'] as String,
          'normalizedName': (cat['name'] as String).trim().toLowerCase(),
          'emoji': cat['emoji'] as String,
          'iconUrl': '',
          'sortOrder': cat['sortOrder'] as int,
          'isActive': true,
          'isPrivate': false,
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    // 4. 193 Artikel in Batches à 490 anlegen.
    final items = kVoilaItems();
    final catNameById = Map.fromEntries(
      kVoilaCategories.map((c) => MapEntry(c['id'] as String, c['name'] as String)),
    );
    for (var i = 0; i < items.length; i += 490) {
      final end = (i + 490 < items.length) ? i + 490 : items.length;
      final batch = firestoreService.batch();
      for (final item in items.sublist(i, end)) {
        final ref = firestoreService.document(
          FirebasePaths.merchantItem(merchantId, item.id),
        );
        batch.set(ref, {
          'id': item.id,
          'merchantId': merchantId,
          'categoryId': item.categoryId,
          'categoryName': catNameById[item.categoryId] ?? '',
          'name': item.name,
          'title': item.name,
          'description': '',
          'price': item.price,
          'originalPrice': null,
          'imageUrl': '',
          'articleNumber': item.nr.toString(),
          'allergenIds': <String>[],
          'additiveIds': <String>[],
          'isActive': true,
          'isAvailable': true,
          'isPrivate': false,
          'isArchived': false,
          'imageRatio': 'square',
          'optionGroups': <Map<String, dynamic>>[],
          'type': 'merchant_item',
          'searchName': item.name.trim().toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> saveShopData(Map<String, dynamic> values) async {
    final typedAddress = _fullAddress(
      values['street']?.toString() ?? '',
      values['houseNumber']?.toString() ?? '',
      values['postalCode']?.toString() ?? '',
      values['city']?.toString() ?? '',
    );
    // Geo: bei jedem Speichern neu kodieren (best effort). Fällt auf die
    // getippte Adresse + bereits vorhandene Koordinaten zurück, wenn kein
    // Geoapify-Key gesetzt ist oder die Anfrage scheitert.
    final geo = await GeoapifyService().forwardGeocode(
      street: values['street']?.toString() ?? '',
      houseNumber: values['houseNumber']?.toString() ?? '',
      postalCode: values['postalCode']?.toString() ?? '',
      city: values['city']?.toString() ?? '',
    );
    final fullAddress =
        (geo?.formatted.isNotEmpty ?? false) ? geo!.formatted : typedAddress;
    final lat = geo?.lat ?? (values['lat'] as num?)?.toDouble();
    final lng = geo?.lng ?? (values['lng'] as num?)?.toDouble();
    final country = values['country']?.toString().trim().isNotEmpty == true
        ? values['country']
        : 'Deutschland';
    // Neues, strukturiertes Adress-Format (Geo-Migration): einzelne Felder +
    // normalisierte Adresse + Koordinaten als eigene Maps.
    final addressData = {
      'street': geo?.street.isNotEmpty == true
          ? geo!.street
          : values['street']?.toString() ?? '',
      'houseNumber': geo?.houseNumber.isNotEmpty == true
          ? geo!.houseNumber
          : values['houseNumber']?.toString() ?? '',
      'postalCode': geo?.postalCode.isNotEmpty == true
          ? geo!.postalCode
          : values['postalCode']?.toString() ?? '',
      'city': geo?.city.isNotEmpty == true
          ? geo!.city
          : values['city']?.toString() ?? '',
      'country': country,
      'formattedAddress': fullAddress,
    };
    final location =
        (lat != null && lng != null) ? {'lat': lat, 'lng': lng} : null;
    final merchantData = {
      ...values,
      'address': fullAddress,
      'fullAddress': fullAddress,
      'lat': lat,
      'lng': lng,
      'addressData': addressData,
      'location': location,
      'country': country,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final shopTypes = (values['shopTypes'] as List?)?.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList() ?? [];
    final profileComplete = _shopProfileComplete(
      values: values,
      fullAddress: fullAddress,
      shopTypes: shopTypes,
    );
    // Sichtbarkeit respektiert das bewusste Opt-out des Merchants (#44) statt
    // bei Vollständigkeit zwangsweise auf public zu kippen.
    final isPublic = profileComplete && values['visibilityOptOut'] != true;
    merchantData['isPublic'] = isPublic;
    merchantData['isActive'] = profileComplete;
    final publicData = {
      'merchantId': merchantId,
      'shopName': values['shopName'],
      'businessName': values['businessName'],
      'description': values['description'],
      'publicNotice': values['publicNotice'],
      'phone': values['phone'],
      'phoneVerified': values['phoneVerified'],
      'street': addressData['street'],
      'houseNumber': addressData['houseNumber'],
      'postalCode': addressData['postalCode'],
      'city': addressData['city'],
      'address': fullAddress,
      'fullAddress': fullAddress,
      'lat': lat,
      'lng': lng,
      'addressData': addressData,
      'location': location,
      'area': values['area'],
      'country': country,
      'shopType': values['shopType'],
      'shopTypePrimary': values['shopTypePrimary'],
      'shopTypes': shopTypes,
      'origins': values['origins'] ?? const <String>[],
      'logoUrl': values['logoUrl'],
      'coverUrl': values['coverUrl'],
      'galleryImages': values['galleryImages'] ?? const <String>[],
      'socialLinks': values['socialLinks'] ?? const <String, String>{},
      'openingHours': values['openingHours'],
      'isPublic': isPublic,
      'isActive': profileComplete,
      'visibilityOptOut': values['visibilityOptOut'] == true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await firestoreService.setDocument(FirebasePaths.merchant(merchantId), merchantData);
    await firestoreService.setDocument(FirebasePaths.publicMerchant(merchantId), publicData);
  }

  Future<void> markPhoneVerified() async {
    final data = {
      'phoneVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await firestoreService.setDocument(FirebasePaths.merchant(merchantId), data);
    await firestoreService.setDocument(FirebasePaths.publicMerchant(merchantId), data);
  }

  Future<List<MerchantFeedPostData>> loadFeedPosts() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantFeedPosts(merchantId))
        .get();
    final posts = snapshot.docs
        .map((doc) => MerchantFeedPostData.fromMap({'postId': doc.id, ...doc.data()}))
        .toList();
    posts.sort((a, b) => (b.updatedAt ?? b.publishedAt ?? b.createdAt ?? DateTime(0))
        .compareTo(a.updatedAt ?? a.publishedAt ?? a.createdAt ?? DateTime(0)));
    return posts;
  }

  Future<void> updateFeedPost(String postId, Map<String, dynamic> values) async {
    final data = {...values, 'updatedAt': FieldValue.serverTimestamp()};
    await firestoreService.setDocument(FirebasePaths.merchantFeedPost(merchantId, postId), data);
    final global = await firestoreService.readDocument(FirebasePaths.feedPost(postId));
    if (global != null) {
      await firestoreService.setDocument(FirebasePaths.feedPost(postId), data);
    }
  }

  Future<List<TableAreaData>> loadTableAreas() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantTableAreas(merchantId))
        .get();
    final areas = snapshot.docs
        .map((doc) => TableAreaData.fromMap({'areaId': doc.id, ...doc.data()}))
        .toList();
    areas.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return areas;
  }

  Future<void> saveTableArea({
    String? areaId,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) async {
    final id = areaId?.isNotEmpty == true
        ? areaId!
        : firestoreService.collection(FirebasePaths.merchantTableAreas(merchantId)).doc().id;
    final isNew = areaId == null || areaId.isEmpty;
    await firestoreService.setDocument(FirebasePaths.merchantTableArea(merchantId, id), {
      'areaId': id,
      'merchantId': merchantId,
      'name': name.trim(),
      'sortOrder': sortOrder,
      'isActive': isActive,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTableArea(String areaId) {
    return firestoreService.document(FirebasePaths.merchantTableArea(merchantId, areaId)).delete();
  }

  Future<List<TableData>> loadTables() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantTables(merchantId))
        .get();
    final tables = snapshot.docs
        .map((doc) => TableData.fromMap({'tableId': doc.id, ...doc.data()}))
        .toList();
    tables.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return tables;
  }

  Future<void> saveTable({
    String? tableId,
    required String areaId,
    required String areaName,
    required String label,
    required int? seats,
    required bool isActive,
  }) async {
    final id = tableId?.isNotEmpty == true
        ? tableId!
        : firestoreService.collection(FirebasePaths.merchantTables(merchantId)).doc().id;
    final isNew = tableId == null || tableId.isEmpty;
    await firestoreService.setDocument(FirebasePaths.merchantTable(merchantId, id), {
      'tableId': id,
      'merchantId': merchantId,
      'areaId': areaId,
      'areaName': areaName,
      'label': label.trim(),
      'seats': seats,
      'qrUrl': '${AppConfig.shopLinkBase}/shop/$merchantId/table/$id',
      'isActive': isActive,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTable(String tableId) {
    return firestoreService.document(FirebasePaths.merchantTable(merchantId, tableId)).delete();
  }
}

class MerchantFeedPostData {
  const MerchantFeedPostData({
    required this.postId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.ctaLabel,
    required this.isActive,
    required this.isArchived,
    required this.isPrivate,
    required this.isScheduled,
    this.viewsCount,
    this.clicksCount,
    this.redemptionsCount,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.scheduledAt,
  });

  final String postId;
  final String title;
  final String subtitle;
  final String description;
  final String type;
  final String imageUrl;
  final String ctaLabel;
  final bool isActive;
  final bool isArchived;
  final bool isPrivate;
  final bool isScheduled;
  final int? viewsCount;
  final int? clicksCount;
  final int? redemptionsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? scheduledAt;

  factory MerchantFeedPostData.fromMap(Map<String, dynamic> map) {
    return MerchantFeedPostData(
      postId: map['postId'] as String? ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: map['type'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      ctaLabel: (map['ctaLabel'] ?? map['buttonText'] ?? '').toString(),
      isActive: map['isActive'] as bool? ?? true,
      isArchived: map['isArchived'] as bool? ?? false,
      isPrivate: map['isPrivate'] as bool? ?? false,
      isScheduled: map['isScheduled'] as bool? ?? false,
      viewsCount: _optionalInt(map, 'viewsCount'),
      clicksCount: _optionalInt(map, 'clicksCount'),
      redemptionsCount: _optionalInt(map, 'redemptionsCount') ?? _optionalInt(map, 'claimsCount'),
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      publishedAt: _date(map['publishedAt']),
      scheduledAt: _date(map['scheduledAt'] ?? map['startDate']),
    );
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}

int? _optionalInt(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key)) return null;
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _normalize(String value) => value.trim().toLowerCase();

String _fullAddress(String street, String houseNumber, String postalCode, String city) {
  final lineOne = [street.trim(), houseNumber.trim()].where((value) => value.isNotEmpty).join(' ');
  final lineTwo = [postalCode.trim(), city.trim()].where((value) => value.isNotEmpty).join(' ');
  return [lineOne, lineTwo].where((value) => value.isNotEmpty).join(', ');
}

bool _shopProfileComplete({
  required Map<String, dynamic> values,
  required String fullAddress,
  required List<String> shopTypes,
}) {
  bool filled(String key) => values[key]?.toString().trim().isNotEmpty == true;
  return filled('shopName') &&
      filled('phone') &&
      values['phoneVerified'] == true &&
      filled('street') &&
      filled('houseNumber') &&
      filled('postalCode') &&
      filled('city') &&
      fullAddress.trim().isNotEmpty &&
      // Area ist Legacy (Stadt + PLZ stecken in der Adresse) und wird für die
      // Vollständigkeit nicht mehr verlangt.
      shopTypes.isNotEmpty &&
      filled('logoUrl') &&
      filled('coverUrl') &&
      values['openingHours'] is Map;
}

