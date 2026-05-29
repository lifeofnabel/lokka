import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import '../services/userPartnersService.dart';

class UserPartnersProvider extends ChangeNotifier {
  UserPartnersProvider({required UserPartnersService service})
      : _service = service {
    _subscribe();
  }

  final UserPartnersService _service;
  StreamSubscription<List<PublicMerchantUserModel>>? _sub;

  List<PublicMerchantUserModel> _partners = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedArea;
  String? _selectedShopType;
  String _searchQuery = '';

  List<PublicMerchantUserModel> get partners {
    if (_searchQuery.isEmpty) return _partners;
    final q = _searchQuery.toLowerCase();
    return _partners
        .where((m) =>
            m.shopName.toLowerCase().contains(q) ||
            m.area.toLowerCase().contains(q))
        .toList();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedArea => _selectedArea;
  String? get selectedShopType => _selectedShopType;
  String get searchQuery => _searchQuery;

  List<String> get availableAreas {
    final areas = _partners.map((m) => m.area).where((a) => a.isNotEmpty).toSet().toList();
    areas.sort();
    return areas;
  }

  List<String> get availableShopTypes {
    final types = _partners.map((m) => m.shopType).where((t) => t.isNotEmpty).toSet().toList();
    types.sort();
    return types;
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter({String? area, String? shopType}) {
    _selectedArea = area;
    _selectedShopType = shopType;
    _subscribe();
  }

  void clearFilters() {
    _selectedArea = null;
    _selectedShopType = null;
    _searchQuery = '';
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();
    _sub = _service
        .partnersStream(area: _selectedArea, shopType: _selectedShopType)
        .listen(
          (list) {
            _partners = list;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
