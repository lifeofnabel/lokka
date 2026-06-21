import 'dart:async';
import 'package:lokka/core/utils/locationUtils.dart';
import 'package:flutter/foundation.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/reviews/models/merchantRating.dart';
import '../services/userPartnersService.dart';

class UserPartnersProvider extends ChangeNotifier {
  UserPartnersProvider({required UserPartnersService service})
      : _service = service {
    _subscribe();
  }

  final UserPartnersService _service;
  StreamSubscription<List<PublicMerchantUserModel>>? _sub;

  // Raw data
  List<PublicMerchantUserModel> _allPartners = [];
  Set<String> _walletIds = {};
  Map<String, int> _beliebtScores = {};
  Map<String, MerchantRating> _ratings = {};
  bool _ratingsLoaded = false;

  // Filter state
  String _searchQuery = '';
  String? _selectedCategory;
  double? _radiusKm;
  bool _walletOnly = false;
  double? _userLat;
  double? _userLng;

  // Loading / error
  bool _isLoading = true;
  String? _error;

  // ── Getters ──────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  double? get radiusKm => _radiusKm;
  bool get walletOnly => _walletOnly;
  double? get userLat => _userLat;
  double? get userLng => _userLng;
  Set<String> get walletIds => _walletIds;
  MerchantRating? ratingFor(String merchantId) => _ratings[merchantId];
  int get totalCount => _allPartners.length;

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != null ||
      _radiusKm != null ||
      _walletOnly;

  List<String> get availableCategories {
    final cats = _allPartners
        .map((m) => m.shopType)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  /// Partners after all active filters are applied.
  List<PublicMerchantUserModel> get filteredPartners {
    var list = _allPartners;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((m) =>
              m.shopName.toLowerCase().contains(q) ||
              m.shopType.toLowerCase().contains(q))
          .toList();
    }
    if (_selectedCategory != null) {
      list = list.where((m) => m.shopType == _selectedCategory).toList();
    }
    if (_walletOnly) {
      list = list.where((m) => _walletIds.contains(m.merchantId)).toList();
    }
    if (_radiusKm != null && _userLat != null && _userLng != null) {
      list = list
          .where((m) =>
              m.hasCoordinates &&
              LocationUtils.distanceKm(_userLat!, _userLng!, m.lat!, m.lng!) <=
                  _radiusKm!)
          .toList();
    }
    return list;
  }

  /// Top 10 by beliebt score, from filtered set.
  List<PublicMerchantUserModel> get beliebtPartners {
    final list = filteredPartners.toList()
      ..sort((a, b) =>
          (_beliebtScores[b.merchantId] ?? 0)
              .compareTo(_beliebtScores[a.merchantId] ?? 0));
    return list.take(10).toList();
  }

  /// Up to 10 newest partners (by updatedAt desc), from filtered set.
  List<PublicMerchantUserModel> get newPartners {
    final list = filteredPartners
        .where((m) => m.updatedAt != null)
        .toList()
      ..sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
    return list.take(10).toList();
  }

  /// Filtered partners grouped by category, categories sorted A–Z.
  Map<String, List<PublicMerchantUserModel>> get partnersByCategory {
    final result = <String, List<PublicMerchantUserModel>>{};
    for (final m in filteredPartners) {
      final cat = m.shopType.isNotEmpty ? m.shopType : 'Sonstiges';
      result.putIfAbsent(cat, () => []).add(m);
    }
    final sorted = Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  // ── Mutators ─────────────────────────────────────────────────────────────

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setFilter({
    String? category,
    double? radiusKm,
    bool? walletOnly,
  }) {
    _selectedCategory = category;
    _radiusKm = radiusKm;
    _walletOnly = walletOnly ?? false;
    notifyListeners();
  }

  void retry() => _subscribe();

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _radiusKm = null;
    _walletOnly = false;
    notifyListeners();
  }

  void updateLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    notifyListeners();
  }

  void updateWalletIds(Set<String> ids) {
    _walletIds = ids;
    notifyListeners();
  }

  void addWalletId(String merchantId) {
    _walletIds = {..._walletIds, merchantId};
    notifyListeners();
  }

  void removeWalletId(String merchantId) {
    _walletIds = _walletIds.where((id) => id != merchantId).toSet();
    notifyListeners();
  }

  Future<void> loadExtras(String uid) async {
    final results = await Future.wait([
      _service.fetchWalletIds(uid),
      _service.fetchBeliebtScores(),
    ]);
    _walletIds = results[0] as Set<String>;
    _beliebtScores = results[1] as Map<String, int>;
    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _subscribe() {
    _sub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();
    _sub = _service.partnersStream().listen(
      (list) {
        _allPartners = list;
        _isLoading = false;
        notifyListeners();
        if (!_ratingsLoaded && list.isNotEmpty) {
          _ratingsLoaded = true;
          _loadRatings(list);
        }
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _loadRatings(List<PublicMerchantUserModel> partners) async {
    final ratings =
        await _service.fetchMerchantRatings(partners.map((m) => m.merchantId));
    if (ratings.isEmpty) return;
    _ratings = ratings;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
