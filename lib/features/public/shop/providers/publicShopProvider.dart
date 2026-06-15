import 'package:flutter/foundation.dart';

import '../../../merchant/catalog/models/itemCategoryData.dart';
import '../../../merchant/catalog/models/itemTagData.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import '../../../merchant/tables/models/merchantTableData.dart';
import '../services/publicShopService.dart';

class PublicCartItem {
  const PublicCartItem({
    required this.item,
    required this.quantity,
  });

  final MerchantItemData item;
  final int quantity;

  num get total => item.price * quantity;

  PublicCartItem copyWith({int? quantity}) {
    return PublicCartItem(
      item: item,
      quantity: quantity ?? this.quantity,
    );
  }
}

class PublicShopProvider extends ChangeNotifier {
  PublicShopProvider({required this.service});

  final PublicShopService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  String selectedCategoryId = 'all';
  Map<String, dynamic>? merchant;
  TableData? table;
  PublicCatalogConfig catalogConfig = PublicCatalogConfig.disabled;
  List<ItemCategoryData> categories = [];
  List<MerchantItemData> items = [];
  List<ItemTagData> itemTags = [];
  List<PublicCartItem> cart = [];
  String? createdOrderId;

  bool get catalogAvailable => catalogConfig.catalogEnabled;
  bool get canOrder => catalogConfig.canOrder(hasTable: table != null);

  List<MerchantItemData> get visibleItems {
    if (selectedCategoryId == 'all') return items;
    return items.where((item) => item.categoryId == selectedCategoryId).toList();
  }

  num get totalPrice => cart.fold<num>(0, (sum, item) => sum + item.total);

  Future<void> load({
    required String merchantId,
    String tableId = '',
  }) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final basics = await Future.wait<Object?>([
        service.loadMerchant(merchantId),
        service.loadTable(merchantId, tableId),
        service.loadCatalogConfig(merchantId),
      ]);
      merchant = basics[0] as Map<String, dynamic>?;
      table = basics[1] as TableData?;
      catalogConfig = basics[2] as PublicCatalogConfig;
      if (!catalogAvailable) {
        categories = [];
        items = [];
        itemTags = [];
        cart = [];
        return;
      }

      final catalog = await Future.wait<Object?>([
        service.loadCategories(merchantId),
        service.loadItemTags(merchantId),
        service.loadItems(merchantId),
      ]);
      categories = catalog[0] as List<ItemCategoryData>;
      itemTags = catalog[1] as List<ItemTagData>;
      items = catalog[2] as List<MerchantItemData>;
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

  void addItem(MerchantItemData item) {
    final next = [...cart];
    final index = next.indexWhere((entry) => entry.item.id == item.id);
    if (index == -1) {
      next.add(PublicCartItem(item: item, quantity: 1));
    } else {
      next[index] = next[index].copyWith(quantity: next[index].quantity + 1);
    }
    cart = next;
    notifyListeners();
  }

  void removeItem(String itemId) {
    final next = [...cart];
    final index = next.indexWhere((entry) => entry.item.id == itemId);
    if (index == -1) return;
    final current = next[index];
    if (current.quantity <= 1) {
      next.removeAt(index);
    } else {
      next[index] = current.copyWith(quantity: current.quantity - 1);
    }
    cart = next;
    notifyListeners();
  }

  Future<bool> placeOrder(String merchantId) async {
    if (cart.isEmpty || !canOrder) return false;
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      createdOrderId = await service.createOrder(
        merchantId: merchantId,
        table: table,
        totalPrice: totalPrice,
        items: cart
            .map((entry) => {
                  'itemId': entry.item.id,
                  'title': entry.item.name,
                  'name': entry.item.name,
                  'quantity': entry.quantity,
                  'unitPrice': entry.item.price,
                  'totalPrice': entry.total,
                  'articleNumber': entry.item.articleNumber,
                })
            .toList(),
      );
      cart = [];
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
