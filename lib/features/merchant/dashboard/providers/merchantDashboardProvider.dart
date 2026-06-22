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

  /// Cover-Fokus aus dem Dashboard neu positionieren. Aktualisiert lokal sofort
  /// (optimistisch) und persistiert in Firestore.
  Future<void> saveCoverFocus(double focusY) async {
    final current = _data;
    if (current == null) return;
    final clamped = focusY.clamp(0.0, 1.0);
    final hero = current.hero;
    final updatedHero = MerchantHeroFields(
      shopName: hero.shopName,
      logoUrl: hero.logoUrl,
      coverUrl: hero.coverUrl,
      coverFocusY: clamped,
      typeLine: hero.typeLine,
      city: hero.city,
    );
    _data = MerchantDashboardData(
      merchant: {...current.merchant, 'coverFocusY': clamped},
      hero: updatedHero,
      metrics: current.metrics,
      moduleActive: current.moduleActive,
      ordersEnabled: current.ordersEnabled,
    );
    notifyListeners();
    try {
      await _service.saveCoverFocus(current.merchantId, clamped);
    } catch (error, stack) {
      debugPrint('MerchantDashboardProvider.saveCoverFocus failed: $error\n$stack');
    }
  }

  Future<void> signOut() => _service.signOut();
}
