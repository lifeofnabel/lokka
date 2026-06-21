import 'package:flutter/foundation.dart';

import '../models/merchantCustomerModel.dart';
import '../services/merchantCustomersService.dart';

enum MerchantCustomerFilter {
  all,
  stampCards,
  pointsSystems,
  coupons,
  orders,
  lastVisited,
}

class MerchantCustomersProvider extends ChangeNotifier {
  MerchantCustomersProvider({required this.service});

  final MerchantCustomersService service;

  bool isLoading = true;

  /// i18n-Key (z. B. 'common.error.network') – die View übersetzt ihn.
  /// Niemals rohe Exception-Strings hier ablegen.
  String? error;
  MerchantCustomerFilter filter = MerchantCustomerFilter.all;
  List<MerchantCustomerModel> customers = [];

  // Memoisiertes Ergebnis: wird nur bei load()/setFilter() neu berechnet, nicht in
  // jedem build(). Immer eine eigene Kopie, damit die Sortierung die geteilte
  // customers-Liste nicht in-place mutiert.
  List<MerchantCustomerModel> _visibleCustomers = [];
  List<MerchantCustomerModel> get visibleCustomers => _visibleCustomers;

  void _recomputeVisible() {
    final result = switch (filter) {
      MerchantCustomerFilter.all => List.of(customers),
      // lastVisited filtert Kunden ohne Besuchsdatum heraus (sonst säße der
      // Chip nur als Sortierung verkleidet als Filter da).
      MerchantCustomerFilter.lastVisited =>
        customers.where((item) => item.lastVisitAt != null).toList(),
      MerchantCustomerFilter.stampCards => customers.where((item) => item.usedSystems.contains('stampCards')).toList(),
      MerchantCustomerFilter.pointsSystems => customers.where((item) => item.usedSystems.contains('pointsSystems')).toList(),
      MerchantCustomerFilter.coupons => customers.where((item) => item.usedSystems.contains('coupons')).toList(),
      MerchantCustomerFilter.orders => customers.where((item) => item.usedSystems.contains('orders')).toList(),
    };
    if (filter == MerchantCustomerFilter.lastVisited) {
      result.sort((a, b) => (b.lastVisitAt ?? DateTime(0)).compareTo(a.lastVisitAt ?? DateTime(0)));
    }
    _visibleCustomers = result;
  }

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      customers = await service.loadCustomers();
      _recomputeVisible();
    } catch (e) {
      error = _errorKey(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(MerchantCustomerFilter value) {
    filter = value;
    _recomputeVisible();
    notifyListeners();
  }

  String _errorKey(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('permission') || text.contains('denied')) {
      return 'common.error.permission';
    }
    if (text.contains('network') || text.contains('unavailable') || text.contains('timeout')) {
      return 'common.error.network';
    }
    return 'common.error.generic';
  }
}
