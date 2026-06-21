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
    } catch (error, stack) {
      // Nutzer sieht eine lokalisierte, generische Meldung; der Roh-Fehler
      // geht nur ins Log (#249). Page mappt _error -> texts.text(_error!).
      _error = 'common.error.generic';
      debugPrint('MerchantDashboardProvider.load failed: $error\n$stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _service.signOut();
}
