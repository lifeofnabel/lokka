import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/orderModel.dart';
import '../services/merchantOrdersService.dart';

class MerchantOrdersProvider extends ChangeNotifier {
  MerchantOrdersProvider({required this.service});

  final MerchantOrdersService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  String filter = 'active';
  List<OrderModel> orders = [];
  OrderModel? selectedOrder;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  StreamSubscription<OrderModel?>? _orderSubscription;

  List<OrderModel> get visibleOrders {
    return switch (filter) {
      'new' => orders.where((order) => order.status == 'new').toList(),
      'preparing' => orders.where((order) => order.status == 'preparing').toList(),
      'done' => orders.where((order) => order.status == 'done').toList(),
      'cancelled' => orders.where((order) => order.status == 'cancelled').toList(),
      'all' => orders,
      _ => orders.where((order) => order.status == 'new' || order.status == 'preparing').toList(),
    };
  }

  int get newCount => orders.where((order) => order.status == 'new').length;
  int get preparingCount => orders.where((order) => order.status == 'preparing').length;
  int get doneCount => orders.where((order) => order.status == 'done').length;
  int get activeCount => newCount + preparingCount;

  Future<void> load({String? orderId}) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      orders = await service.loadOrders();
      if (orderId != null && orderId.isNotEmpty) {
        selectedOrder = _find(orderId) ?? await service.loadOrder(orderId);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void watch({String? orderId}) {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      _ordersSubscription?.cancel();
      _ordersSubscription = service.watchOrders().listen(
        (nextOrders) {
          orders = nextOrders;
          if (orderId != null && orderId.isNotEmpty) {
            selectedOrder = _find(orderId);
          }
          isLoading = false;
          error = null;
          notifyListeners();
        },
        onError: (Object e) {
          error = e.toString();
          isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  /// Beobachtet NUR die eine Bestellung (Detailseite, #5) – nicht die ganze
  /// orders-Collection.
  void watchSingle(String orderId) {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      _ordersSubscription?.cancel();
      _orderSubscription?.cancel();
      _orderSubscription = service.watchOrder(orderId).listen(
        (order) {
          selectedOrder = order;
          isLoading = false;
          error = null;
          notifyListeners();
        },
        onError: (Object e) {
          error = e.toString();
          isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String value) {
    filter = value;
    notifyListeners();
  }

  Future<void> updateStatus(String orderId, String status) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await service.updateStatus(orderId, status);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  OrderModel? _find(String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }
}
