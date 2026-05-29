import 'package:flutter/foundation.dart';

import '../services/merchantDashboardService.dart';

class MerchantDashboardProvider extends ChangeNotifier {
  MerchantDashboardProvider({required MerchantDashboardService service}) : _service = service;

  final MerchantDashboardService _service;

  MerchantDashboardData? _data;
  bool _isLoading = true;
  String? _error;

  MerchantDashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _service.loadDashboard();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _service.signOut();
}
