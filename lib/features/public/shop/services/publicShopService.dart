import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../merchant/catalog/models/itemCategoryData.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import '../../../merchant/tables/models/merchantTableData.dart';

class PublicShopService {
  const PublicShopService({
    required this.firestoreService,
  });

  final FirestoreService firestoreService;

  Future<Map<String, dynamic>?> loadMerchant(String merchantId) {
    return firestoreService.readDocument(FirebasePaths.publicMerchant(merchantId));
  }

  Future<TableData?> loadTable(String merchantId, String tableId) async {
    if (tableId.trim().isEmpty) return null;
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantTable(merchantId, tableId),
    );
    if (data == null) return null;
    final table = TableData.fromMap({'tableId': tableId, ...data});
    return table.isActive ? table : null;
  }

  Future<PublicCatalogConfig> loadCatalogConfig(String merchantId) async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantFeatureConfig(merchantId, 'menuCatalog'),
    );
    if (data == null) return PublicCatalogConfig.disabled;

    final isEnabled = data['isEnabled'] == true ||
        data['isActive'] == true ||
        data['status'] == 'enabled' ||
        data['status'] == 'active';
    final settings = data['settings'];
    if (!isEnabled || settings is! Map) {
      return PublicCatalogConfig(catalogEnabled: isEnabled);
    }

    return PublicCatalogConfig(
      catalogEnabled: isEnabled,
      orderQrCashier: settings['catalogOrderQrCashier'] == true,
      orderSendCashier: settings['catalogOrderSendCashier'] == true,
      tableOrders: settings['catalogTableOrders'] == true,
    );
  }

  Future<List<ItemCategoryData>> loadCategories(String merchantId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItemCategories(merchantId))
        .get();
    final categories = snapshot.docs
        .map((doc) => ItemCategoryData.fromMap({'id': doc.id, ...doc.data()}))
        .where((category) => category.isActive && !category.isPrivate && !category.isArchived)
        .toList();
    categories.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return categories;
  }

  Future<List<MerchantItemData>> loadItems(String merchantId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItems(merchantId))
        .get();
    final items = snapshot.docs
        .map((doc) => MerchantItemData.fromMap({'id': doc.id, ...doc.data()}))
        .where((item) => item.isActive && item.isAvailable && !item.isPrivate && !item.isArchived)
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<String> createOrder({
    required String merchantId,
    required List<Map<String, dynamic>> items,
    required num totalPrice,
    TableData? table,
  }) async {
    final orderId = firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .doc()
        .id;
    final orderCode = 'LK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await firestoreService.setDocument(
      FirebasePaths.merchantOrder(merchantId, orderId),
      {
        'id': orderId,
        'orderId': orderId,
        'merchantId': merchantId,
        'orderCode': orderCode,
        'status': 'new',
        'orderType': table == null ? 'catalog' : 'table',
        'placeLabel': table == null ? 'Speisekarte' : table.label,
        'tableId': table?.tableId ?? '',
        'tableLabel': table?.label ?? '',
        'areaId': table?.areaId ?? '',
        'areaName': table?.areaName ?? '',
        'customerName': 'Gast',
        'items': items,
        'totalPrice': totalPrice,
        'isDemo': false,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    return orderId;
  }
}

class PublicCatalogConfig {
  const PublicCatalogConfig({
    required this.catalogEnabled,
    this.orderQrCashier = false,
    this.orderSendCashier = false,
    this.tableOrders = false,
  });

  static const disabled = PublicCatalogConfig(catalogEnabled: false);

  final bool catalogEnabled;
  final bool orderQrCashier;
  final bool orderSendCashier;
  final bool tableOrders;

  bool canOrder({required bool hasTable}) {
    if (!catalogEnabled) return false;
    if (hasTable) return tableOrders;
    return orderQrCashier || orderSendCashier;
  }
}
