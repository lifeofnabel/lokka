import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/orderModel.dart';
import '../services/merchantOrdersService.dart';

/// Start des Geschäftstags = heute 06:00 (oder gestern 06:00, wenn es jetzt
/// noch vor 06:00 ist). Lokale Zeit (Annahme: Gerät steht auf Europe/Berlin).
/// So „rollt" der Tageszähler automatisch jeden Morgen um 6 Uhr – ohne Job.
DateTime businessDayStart([DateTime? now]) {
  final t = now ?? DateTime.now();
  final sixToday = DateTime(t.year, t.month, t.day, 6);
  return t.isBefore(sixToday)
      ? sixToday.subtract(const Duration(days: 1))
      : sixToday;
}

/// Tagesumsatz (≈) für die Speisekarte-Seite (nur Runner-Modus). Live über die
/// orders-Collection; Pause liegt pro Konto im Merchant-Doc.
class MerchantDailyRevenueProvider extends ChangeNotifier {
  MerchantDailyRevenueProvider({required this.service});

  final MerchantOrdersService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  bool paused = false;
  List<OrderModel> _orders = const [];
  StreamSubscription<List<OrderModel>>? _sub;

  void start() {
    _loadPause();
    _sub?.cancel();
    _sub = service.watchOrders().listen(
      (next) {
        _orders = next;
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
  }

  Future<void> _loadPause() async {
    try {
      paused = await service.loadRevenuePaused();
      notifyListeners();
    } catch (_) {/* Default: nicht pausiert */}
  }

  Future<void> togglePause() async {
    isSaving = true;
    notifyListeners();
    try {
      paused = !paused;
      await service.setRevenuePaused(paused);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  bool _paidToday(OrderModel o) {
    final p = o.paidAt;
    return o.paid &&
        !o.excludeFromDaily &&
        p != null &&
        !p.isBefore(businessDayStart());
  }

  /// Bezahlt heute (≈) – ohne während Pause abgeschlossene.
  num get paidToday =>
      _orders.where(_paidToday).fold<num>(0, (s, o) => s + o.totalPrice);

  int get paidTodayCount => _orders.where(_paidToday).length;

  /// Noch offen (unbezahlt, nicht storniert) – „hängt noch an Tischen".
  num get openTotal => _orders
      .where((o) => !o.paid && o.status != 'cancelled')
      .fold<num>(0, (s, o) => s + o.totalPrice);

  /// Offene Bestellungen von VOR dem heutigen Geschäftstag → am Tagesende
  /// nachzubuchen (erzwungenes Settle).
  List<OrderModel> get leftovers {
    final start = businessDayStart();
    return _orders
        .where((o) =>
            !o.paid &&
            o.status != 'cancelled' &&
            o.createdAt != null &&
            o.createdAt!.isBefore(start))
        .toList();
  }

  /// Die übergebenen offenen Bestellungen als bezahlt nachbuchen.
  Future<void> settle(List<OrderModel> open) async {
    if (open.isEmpty) return;
    isSaving = true;
    notifyListeners();
    try {
      for (final order in open) {
        await service.closeOrderPaid(order.id, excludeFromDaily: paused);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Zeitraum-Auswahl für die Finanzen-Seite.
enum FinancePeriod { today, yesterday, week, month, custom }

/// Finanzen-Auswertung (Dashboard, nur Runner-Modus): Gesamt-Umsatz (bezahlt)
/// je Zeitraum + Aufteilung pro Runner. Einmaliger Lade-Vorgang pro Zeitraum.
class MerchantFinanceProvider extends ChangeNotifier {
  MerchantFinanceProvider({required this.service});

  final MerchantOrdersService service;

  bool isLoading = false;
  String? error;
  FinancePeriod period = FinancePeriod.today;
  DateTime? _customStart;
  DateTime? _customEnd;
  List<OrderModel> _paid = const [];

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final range = _range();
      _paid = await service.loadPaidOrdersBetween(range.start, range.end);
    } catch (e) {
      error = e.toString();
      _paid = const [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setPeriod(FinancePeriod next) {
    period = next;
    load();
  }

  void setCustomRange(DateTime start, DateTime endInclusive) {
    period = FinancePeriod.custom;
    _customStart = DateTime(start.year, start.month, start.day, 6);
    // Ende inklusiv → bis 6 Uhr des Folgetags.
    _customEnd = DateTime(endInclusive.year, endInclusive.month, endInclusive.day, 6)
        .add(const Duration(days: 1));
    load();
  }

  ({DateTime start, DateTime? end}) _range() {
    final start6 = businessDayStart();
    switch (period) {
      case FinancePeriod.today:
        return (start: start6, end: null);
      case FinancePeriod.yesterday:
        return (
          start: start6.subtract(const Duration(days: 1)),
          end: start6,
        );
      case FinancePeriod.week:
        return (start: start6.subtract(const Duration(days: 7)), end: null);
      case FinancePeriod.month:
        return (start: start6.subtract(const Duration(days: 30)), end: null);
      case FinancePeriod.custom:
        return (start: _customStart ?? start6, end: _customEnd);
    }
  }

  num get total => _paid.fold<num>(0, (s, o) => s + o.totalPrice);
  int get count => _paid.length;

  /// Pro Runner: runnerId → (Anzahl, Summe, Name). Name aus customerName der
  /// Bestellung (= Runner-Name). Leerer Key = ohne Runner-Zuordnung.
  List<({String runnerId, String name, int count, num total})> get perRunner {
    final map = <String, ({String name, int count, num total})>{};
    for (final o in _paid) {
      final key = o.runnerId;
      final cur = map[key];
      map[key] = (
        name: o.customerName.trim().isNotEmpty
            ? o.customerName.trim()
            : (cur?.name ?? ''),
        count: (cur?.count ?? 0) + 1,
        total: (cur?.total ?? 0) + o.totalPrice,
      );
    }
    final list = map.entries
        .map((e) => (
              runnerId: e.key,
              name: e.value.name,
              count: e.value.count,
              total: e.value.total,
            ))
        .toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }
}
