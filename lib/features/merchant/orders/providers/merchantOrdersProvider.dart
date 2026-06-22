import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../catalog/models/runnerData.dart';
import '../models/orderModel.dart';
import '../services/merchantOrdersService.dart';

class MerchantOrdersProvider extends ChangeNotifier {
  MerchantOrdersProvider({required this.service});

  final MerchantOrdersService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  String filter = 'all'; // all (= Neue + In Arbeit) | new | preparing | done | cancelled
  String tableAreaFilter = 'all'; // Bereich-Filter der Tisch-Einsicht ('' = ohne Bereich)
  String search = '';
  List<OrderModel> orders = [];
  List<RunnerData> runners = [];
  OrderModel? selectedOrder;

  /// Zählt hoch, sobald eine NEUE Bestellung (Status „new") eintrifft – die UI
  /// löst daraufhin den Alarm aus. Beim ersten Laden wird NICHT alarmiert.
  int newOrderSignal = 0;
  final Set<String> _seenNewIds = {};
  bool _alertInitialized = false;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  StreamSubscription<OrderModel?>? _orderSubscription;

  /// Status + Suche kombiniert (Reihenfolge bleibt jüngste zuerst).
  List<OrderModel> get visibleOrders => orders
      .where((order) => _matchesStatus(order) && _matchesSearch(order))
      .toList();

  bool _matchesStatus(OrderModel order) {
    return switch (filter) {
      'new' => order.status == 'new',
      'preparing' => order.status == 'preparing',
      'done' => order.status == 'done',
      'cancelled' => order.status == 'cancelled',
      // „Alle" zeigt bewusst nur die aktiven Bestellungen (Neue + In Arbeit).
      _ => order.isOpen,
    };
  }

  bool _matchesSearch(OrderModel order) {
    final query = search.trim().toLowerCase();
    if (query.isEmpty) return true;
    return order.orderCode.toLowerCase().contains(query) ||
        order.placeLabel.toLowerCase().contains(query) ||
        order.tableLabel.toLowerCase().contains(query) ||
        order.itemsText.toLowerCase().contains(query);
  }

  String runnerNameOf(String id) {
    if (id.isEmpty) return '';
    for (final r in runners) {
      if (r.id == id) return r.name;
    }
    return '';
  }

  int get newCount => orders.where((order) => order.status == 'new').length;
  int get preparingCount => orders.where((order) => order.status == 'preparing').length;
  int get doneCount => orders.where((order) => order.status == 'done').length;
  int get activeCount => newCount + preparingCount;

  /// Bereich eines Tisches (leer = „Ohne Bereich").
  String areaOf(OrderModel order) => order.areaName.trim();

  /// Distinkte Bereiche aller aktiven Tisch-Bestellungen – für den Bereich-
  /// Filter der Tisch-Einsicht. '' steht für „Ohne Bereich".
  List<String> get tableAreaNames {
    final set = <String>{};
    for (final order in orders) {
      if (!order.isTableOrder || order.status == 'cancelled') continue;
      set.add(areaOf(order));
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Aktive Tisch-Bestellungen, gruppiert nach Tisch (Tisch-Einsicht),
  /// optional auf einen Bereich gefiltert. Stornierte werden ausgeblendet.
  Map<String, List<OrderModel>> get tableGroups {
    final groups = <String, List<OrderModel>>{};
    for (final order in orders) {
      if (!order.isTableOrder ||
          order.status == 'cancelled' ||
          order.cleared) {
        continue;
      }
      if (tableAreaFilter != 'all' && areaOf(order) != tableAreaFilter) continue;
      groups.putIfAbsent(order.tableKey, () => []).add(order);
    }
    return groups;
  }

  /// Alle (auch erledigten) Bestellungen eines Tisches – für die Tisch-Detailseite.
  List<OrderModel> ordersForTable(String tableKey) => orders
      .where((order) =>
          order.isTableOrder && order.tableKey == tableKey && !order.cleared)
      .toList();

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
    service.loadRunners().then((list) {
      runners = list;
      notifyListeners();
    }).catchError((_) {/* runner names are cosmetic, non-blocking */});
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      _ordersSubscription?.cancel();
      _ordersSubscription = service.watchOrders().listen(
        (nextOrders) {
          orders = nextOrders;
          _detectNewOrders(nextOrders);
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

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void setTableAreaFilter(String value) {
    tableAreaFilter = value;
    notifyListeners();
  }

  /// „Tisch abschließen": markiert alle noch offenen Bestellungen des Tisches
  /// als fertig. Danach hat der Tisch keine offenen Bestellungen mehr und gilt
  /// als beendet.
  Future<void> closeTable(String tableKey) async {
    // Alle nicht-stornierten, noch unbezahlten Bestellungen des Tisches
    // abschließen = fertig + bezahlt (auch schon „fertige"). Während einer
    // Tagesumsatz-Pause zählen sie nicht in den Tageszähler.
    final toClose = orders
        .where((o) =>
            o.isTableOrder &&
            o.tableKey == tableKey &&
            o.status != 'cancelled' &&
            !o.paid)
        .toList();
    if (toClose.isEmpty) return;
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final paused = await service.loadRevenuePaused();
      for (final order in toClose) {
        await service.closeOrderPaid(order.id, excludeFromDaily: paused);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// „Tisch aufräumen": ALLE nicht-stornierten Bestellungen (auch vorbereitete/
  /// fertige) als bezahlt zählen (falls noch offen) und den Tisch aus der
  /// Tisch-Einsicht entfernen (cleared).
  Future<void> cleanTable(String tableKey) async {
    final list = orders
        .where((o) =>
            o.isTableOrder && o.tableKey == tableKey && o.status != 'cancelled')
        .toList();
    if (list.isEmpty) return;
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final paused = await service.loadRevenuePaused();
      for (final order in list) {
        await service.clearOrder(order.id,
            markPaid: !order.paid, excludeFromDaily: paused);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Vor-Kasse-Bestellung per Code bestätigen (Kasse). Gibt true bei Erfolg.
  Future<bool> confirmByCode(String code) async {
    try {
      return await service.confirmPendingByCode(code);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
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

  /// Erkennt frisch eingetroffene „new"-Bestellungen (für den Alarm). Beim
  /// ersten Stream-Ereignis werden bestehende nur gemerkt, nicht gemeldet.
  void _detectNewOrders(List<OrderModel> next) {
    final currentNew =
        next.where((o) => o.status == 'new').map((o) => o.id).toSet();
    if (!_alertInitialized) {
      _seenNewIds
        ..clear()
        ..addAll(currentNew);
      _alertInitialized = true;
      return;
    }
    final fresh = currentNew.difference(_seenNewIds);
    if (fresh.isNotEmpty) newOrderSignal += fresh.length;
    _seenNewIds
      ..clear()
      ..addAll(currentNew);
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
