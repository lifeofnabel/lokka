import 'package:flutter/foundation.dart';

import '../models/merchantCustomerModel.dart';
import '../services/merchantCustomersService.dart';

/// Follower-Liste des Merchants. Früher „Kunden" mit 7 Filter-Chips – die
/// Programm-Filter (Stempel/Punkte/Coupons/Bestellungen) waren tote Filter:
/// `usedSystems` wird beim Folgen immer nur mit `['follower']` befüllt, die
/// Chips lieferten nie Treffer. Jetzt: Follower + Namens-Suche, fertig.
class MerchantCustomersProvider extends ChangeNotifier {
  MerchantCustomersProvider({required this.service});

  final MerchantCustomersService service;

  bool isLoading = true;

  /// i18n-Key (z. B. 'common.error.network') – die View übersetzt ihn.
  /// Niemals rohe Exception-Strings hier ablegen.
  String? error;
  String search = '';
  List<MerchantCustomerModel> customers = [];

  // Memoisiertes Ergebnis: wird nur bei load()/setSearch() neu berechnet, nicht
  // in jedem build(). Immer eine eigene Kopie, damit die Sortierung die
  // geteilte customers-Liste nicht in-place mutiert.
  List<MerchantCustomerModel> _visibleCustomers = [];
  List<MerchantCustomerModel> get visibleCustomers => _visibleCustomers;

  /// Gesamtzahl der Follower (unabhängig von der Suche) – für den Zähler im
  /// Seitenkopf.
  int get followerCount => customers.length;

  void _recomputeVisible() {
    final query = search.trim().toLowerCase();
    final result = query.isEmpty
        ? List.of(customers)
        : customers
            .where((item) => item.name.toLowerCase().contains(query))
            .toList();
    // Neueste Follower zuerst; ohne Folge-Datum ans Ende.
    result.sort((a, b) => (b.followedAt ?? b.lastVisitAt ?? DateTime(0))
        .compareTo(a.followedAt ?? a.lastVisitAt ?? DateTime(0)));
    _visibleCustomers = result;
  }

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final loaded = await service.loadCustomers();
      // Defensiv nur Follower zeigen – andere Datensätze existieren im
      // Normalfall nicht (Folgen ist der einzige Schreibpfad), aber falls doch,
      // gehören sie nicht in diese Liste.
      customers = loaded.where((item) => item.isFollower).toList();
      _recomputeVisible();
    } catch (e) {
      error = _errorKey(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setSearch(String value) {
    search = value;
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
