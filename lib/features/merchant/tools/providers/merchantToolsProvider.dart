import 'package:flutter/foundation.dart';

import '../../../../core/services/uploadService.dart';
import '../services/merchantToolsService.dart';

class MerchantCategoriesProvider extends ChangeNotifier {
  MerchantCategoriesProvider({
    required this.service,
    required this.uploadService,
  });

  final MerchantToolsService service;
  final UploadService uploadService;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<ItemCategoryData> categories = [];

  Future<void> load() async {
    await _guard(() async {
      isLoading = true;
      notifyListeners();
      categories = await service.loadCategories();
    });
    isLoading = false;
    notifyListeners();
  }

  Future<String?> uploadIcon() async {
    try {
      isSaving = true;
      notifyListeners();
      final media = await uploadService.pickAndUploadOptimizedImage(type: UploadImageType.categoryIcon);
      return media?.secureUrl.isNotEmpty == true ? media!.secureUrl : media?.url;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
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
    await _saving(() => service.saveCategory(
          id: id,
          name: name,
          emoji: emoji,
          iconUrl: iconUrl,
          sortOrder: sortOrder,
          isActive: isActive,
          isPrivate: isPrivate,
        ));
    await load();
  }

  Future<bool> categoryHasItems(String categoryId) => service.categoryHasItems(categoryId);

  Future<void> deleteCategory(String categoryId) async {
    await _saving(() => service.deleteCategory(categoryId));
    await load();
  }

  Future<void> moveCategory(ItemCategoryData category, int direction) async {
    final index = categories.indexWhere((item) => item.id == category.id);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= categories.length) return;
    final target = categories[targetIndex];
    await _saving(() async {
      await service.saveCategory(
        id: category.id,
        name: category.name,
        emoji: category.emoji,
        iconUrl: category.iconUrl,
        sortOrder: target.sortOrder,
        isActive: category.isActive,
        isPrivate: category.isPrivate,
      );
      await service.saveCategory(
        id: target.id,
        name: target.name,
        emoji: target.emoji,
        iconUrl: target.iconUrl,
        sortOrder: category.sortOrder,
        isActive: target.isActive,
        isPrivate: target.isPrivate,
      );
    });
    await load();
  }

  Future<void> _saving(Future<void> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      error = null;
      await action();
    } catch (e) {
      error = e.toString();
    }
  }
}

class MerchantItemsProvider extends ChangeNotifier {
  MerchantItemsProvider({
    required this.service,
    required this.uploadService,
  });

  final MerchantToolsService service;
  final UploadService uploadService;

  bool isLoading = true;
  bool isSaving = false;
  double? uploadProgress;
  String? error;
  String selectedCategoryId = 'all';
  String _search = '';
  List<ItemCategoryData> categories = [];
  List<MerchantItemData> items = [];
  List<ItemTagData> itemTags = [];

  List<MerchantItemData> get visibleItems {
    final q = _search.trim().toLowerCase();
    return items.where((item) {
      final matchesCat =
          selectedCategoryId == 'all' || item.categoryId == selectedCategoryId;
      if (!matchesCat) return false;
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
          item.articleNumber.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      categories = await service.loadCategories();
      itemTags = await service.loadItemTags();
      items = await service.loadItems();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String id) {
    selectedCategoryId = id;
    notifyListeners();
  }

  void setSearch(String query) {
    _search = query;
    notifyListeners();
  }

  Future<String?> uploadImage({bool wide = false}) async {
    try {
      isSaving = true;
      notifyListeners();
      final media = await uploadService.pickAndUploadOptimizedImage(
        type: wide ? UploadImageType.itemWide : UploadImageType.item,
      );
      return media?.secureUrl.isNotEmpty == true ? media!.secureUrl : media?.url;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> uploadCroppedImage({
    required Uint8List bytes,
    required String fileName,
    required UploadImageType type,
  }) async {
    try {
      uploadProgress = 0;
      isSaving = true;
      error = null;
      notifyListeners();
      final media = await uploadService.uploadOptimizedImageBytes(
        bytes: bytes,
        fileName: fileName,
        type: type,
        onProgress: (p) {
          uploadProgress = p;
          notifyListeners();
        },
      );
      return media.secureUrl.isNotEmpty ? media.secureUrl : media.url;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      uploadProgress = null;
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> saveItem({
    String? id,
    required String categoryId,
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
    final matchingCategories = categories.where((item) => item.id == categoryId).toList();
    if (matchingCategories.isEmpty) {
      error = 'merchant.items.chooseCategory';
      notifyListeners();
      return;
    }
    final category = matchingCategories.first;
    await _saving(() => service.saveItem(
          id: id,
          categoryId: categoryId,
          categoryName: category.name,
          name: name,
          description: description,
          price: price,
          originalPrice: originalPrice,
          imageUrl: imageUrl,
          articleNumber: articleNumber,
          allergenIds: allergenIds,
          additiveIds: additiveIds,
          isActive: isActive,
          isAvailable: isAvailable,
          isPrivate: isPrivate,
          imageRatio: imageRatio,
          optionGroups: optionGroups,
        ));
    await load();
  }

  Future<void> deleteItem(String itemId) async {
    await _saving(() => service.deleteItem(itemId));
    await load();
  }

  Future<void> seedCatalog() async {
    await _saving(() => service.seedCatalog());
    await load();
  }

  Future<void> _saving(Future<void> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

class MerchantItemTagsProvider extends ChangeNotifier {
  MerchantItemTagsProvider({required this.service});

  final MerchantToolsService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<ItemTagData> tags = [];

  List<ItemTagData> get allergens => tags.where((tag) => tag.type == ItemTagType.allergen).toList();
  List<ItemTagData> get additives => tags.where((tag) => tag.type == ItemTagType.additive).toList();

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      tags = await service.loadItemTags();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTag({
    String? id,
    required String type,
    required String code,
    required String name,
  }) async {
    await _saving(() => service.saveItemTag(
          id: id,
          type: type,
          code: code,
          name: name,
        ));
    await load();
  }

  Future<void> deleteTag(String tagId) async {
    await _saving(() => service.deleteItemTag(tagId));
    await load();
  }

  Future<void> _saving(Future<void> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

class MerchantShopProvider extends ChangeNotifier {
  MerchantShopProvider({
    required this.service,
    required this.uploadService,
  });

  final MerchantToolsService service;
  final UploadService uploadService;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  Map<String, dynamic>? merchant;
  List<String> shopTypes = [];

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final result = await Future.wait<Object?>([
        service.loadMerchant(),
        service.loadChooserShopTypes(),
      ]);
      merchant = result[0] as Map<String, dynamic>?;
      final loadedShopTypes = result[1] as List<String>;
      shopTypes = loadedShopTypes.isEmpty ? _fallbackShopTypes : loadedShopTypes;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadImage(UploadImageType type) async {
    try {
      isSaving = true;
      notifyListeners();
      final media = await uploadService.pickAndUploadOptimizedImage(type: type);
      return media?.secureUrl.isNotEmpty == true ? media!.secureUrl : media?.url;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await service.saveShopData(data);
      merchant = {...?merchant, ...data};
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> markPhoneVerified() async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await service.markPhoneVerified();
      merchant = {...?merchant, 'phoneVerified': true};
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

class MerchantFeedManageProvider extends ChangeNotifier {
  MerchantFeedManageProvider({required this.service});

  final MerchantToolsService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<MerchantFeedPostData> posts = [];

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      posts = await service.loadFeedPosts();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePost(String postId, Map<String, dynamic> values) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await service.updateFeedPost(postId, values);
      await load();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

class MerchantTablesProvider extends ChangeNotifier {
  MerchantTablesProvider({required this.service});

  final MerchantToolsService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  String selectedAreaId = 'all';
  List<TableAreaData> areas = [];
  List<TableData> tables = [];

  List<TableData> get visibleTables {
    if (selectedAreaId == 'all') return tables;
    return tables.where((table) => table.areaId == selectedAreaId).toList();
  }

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      areas = await service.loadTableAreas();
      tables = await service.loadTables();
      if (selectedAreaId != 'all' && !areas.any((area) => area.areaId == selectedAreaId)) {
        selectedAreaId = 'all';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectArea(String areaId) {
    selectedAreaId = areaId;
    notifyListeners();
  }

  Future<void> saveArea({
    String? areaId,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) async {
    await _saving(() => service.saveTableArea(
          areaId: areaId,
          name: name,
          sortOrder: sortOrder,
          isActive: isActive,
        ));
    await load();
  }

  Future<void> deleteArea(String areaId) async {
    await _saving(() => service.deleteTableArea(areaId));
    await load();
  }

  Future<void> moveArea(TableAreaData area, int direction) async {
    final index = areas.indexWhere((item) => item.areaId == area.areaId);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= areas.length) return;
    final target = areas[targetIndex];
    await _saving(() async {
      await service.saveTableArea(
        areaId: area.areaId,
        name: area.name,
        sortOrder: target.sortOrder,
        isActive: area.isActive,
      );
      await service.saveTableArea(
        areaId: target.areaId,
        name: target.name,
        sortOrder: area.sortOrder,
        isActive: target.isActive,
      );
    });
    await load();
  }

  Future<void> saveTable({
    String? tableId,
    required String areaId,
    required String label,
    required int? seats,
    required bool isActive,
  }) async {
    final matches = areas.where((area) => area.areaId == areaId).toList();
    if (matches.isEmpty) {
      error = 'merchant.tables.chooseArea';
      notifyListeners();
      return;
    }
    await _saving(() => service.saveTable(
          tableId: tableId,
          areaId: areaId,
          areaName: matches.first.name,
          label: label,
          seats: seats,
          isActive: isActive,
        ));
    await load();
  }

  Future<void> deleteTable(String tableId) async {
    await _saving(() => service.deleteTable(tableId));
    await load();
  }

  Future<void> _saving(Future<void> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

const _fallbackShopTypes = ['Food', 'Cafe', 'Kiosk', 'Beauty', 'Barber', 'Fitness', 'Retail', 'Service'];

/// Verwaltung der Runner (Name + PIN) für den Runner-Modus.
class MerchantRunnersProvider extends ChangeNotifier {
  MerchantRunnersProvider({required this.service});

  final MerchantToolsService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<RunnerData> runners = [];

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      runners = await service.loadRunners();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  int _seq = 0;

  Future<void> addRunner(String name) {
    final id = 'r${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    return _save([...runners, RunnerData(id: id, name: name.trim())]);
  }

  Future<void> renameRunner(String id, String name) {
    return _save([
      for (final runner in runners)
        if (runner.id == id) runner.copyWith(name: name.trim()) else runner,
    ]);
  }

  /// Verfügbarkeit umschalten (wer steht zur Auswahl in der Karte?).
  Future<void> setAvailable(String id, bool available) {
    return _save([
      for (final runner in runners)
        if (runner.id == id) runner.copyWith(available: available) else runner,
    ]);
  }

  Future<void> deleteRunner(String id) {
    return _save(runners.where((runner) => runner.id != id).toList());
  }

  Future<void> _save(List<RunnerData> next) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await service.saveRunners(next);
      runners = next;
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
