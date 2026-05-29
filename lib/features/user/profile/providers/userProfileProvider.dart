import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lokka/core/models/appUserModel.dart';
import '../services/userProfileService.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider({required UserProfileService service})
      : _service = service {
    _subscribe();
    _loadCounts();
  }

  final UserProfileService _service;
  StreamSubscription<AppUserModel?>? _sub;

  AppUserModel? _user;
  bool _isLoading = true;
  String? _error;
  int _walletCount = 0;
  int _rewardsCount = 0;
  int _couponsCount = 0;

  AppUserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get walletCount => _walletCount;
  int get rewardsCount => _rewardsCount;
  int get couponsCount => _couponsCount;
  UserProfileService get service => _service;

  void _subscribe() {
    _sub = _service.profileStream().listen(
      (user) {
        _user = user;
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

  Future<void> _loadCounts() async {
    final results = await Future.wait([
      _service.walletCount(),
      _service.rewardsCount(),
      _service.couponsCount(),
    ]);
    _walletCount = results[0];
    _rewardsCount = results[1];
    _couponsCount = results[2];
    notifyListeners();
  }

  Future<void> signOut() => _service.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
