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
  String? error;
  MerchantCustomerFilter filter = MerchantCustomerFilter.all;
  List<MerchantCustomerModel> customers = [];

  List<MerchantCustomerModel> get visibleCustomers {
    final result = switch (filter) {
      MerchantCustomerFilter.all || MerchantCustomerFilter.lastVisited => customers,
      MerchantCustomerFilter.stampCards => customers.where((item) => item.usedSystems.contains('stampCards')).toList(),
      MerchantCustomerFilter.pointsSystems => customers.where((item) => item.usedSystems.contains('pointsSystems')).toList(),
      MerchantCustomerFilter.coupons => customers.where((item) => item.usedSystems.contains('coupons')).toList(),
      MerchantCustomerFilter.orders => customers.where((item) => item.usedSystems.contains('orders')).toList(),
    };
    if (filter == MerchantCustomerFilter.lastVisited) {
      result.sort((a, b) => (b.lastVisitAt ?? DateTime(0)).compareTo(a.lastVisitAt ?? DateTime(0)));
    }
    return result;
  }

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      customers = await service.loadCustomers();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(MerchantCustomerFilter value) {
    filter = value;
    notifyListeners();
  }
}
