import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/feedPostModel.dart';
import '../services/userFeedService.dart';

class UserFeedProvider extends ChangeNotifier {
  UserFeedProvider({required UserFeedService service}) : _service = service {
    _subscribe();
  }

  final UserFeedService _service;
  StreamSubscription<List<FeedPostModel>>? _sub;

  List<FeedPostModel> _posts = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedArea;
  String? _selectedShopType;

  List<FeedPostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedArea => _selectedArea;
  String? get selectedShopType => _selectedShopType;

  UserFeedService get service => _service;

  List<String> get availableAreas {
    final areas = _posts.map((p) => p.merchantArea).where((a) => a.isNotEmpty).toSet().toList();
    areas.sort();
    return areas;
  }

  List<String> get availableShopTypes {
    final types = _posts.map((p) => p.merchantShopType).where((t) => t.isNotEmpty).toSet().toList();
    types.sort();
    return types;
  }

  void setFilter({String? area, String? shopType}) {
    _selectedArea = area;
    _selectedShopType = shopType;
    _subscribe();
  }

  void clearFilters() {
    _selectedArea = null;
    _selectedShopType = null;
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();
    _sub = _service
        .feedStream(area: _selectedArea, shopType: _selectedShopType)
        .listen(
          (list) {
            _posts = list;
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
