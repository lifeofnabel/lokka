import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lokka/core/utils/deferredWarmup.dart';
import '../models/walletCardModel.dart';
import '../services/userWalletService.dart';

class UserWalletProvider extends ChangeNotifier {
  /// [tabIndex] lässt den Start verzögern, solange ein anderer Tab aktiv ist
  /// (siehe [DeferredWarmup]) – null startet sofort (Default/Testverhalten).
  UserWalletProvider({required UserWalletService service, int? tabIndex})
      : _service = service {
    if (tabIndex == null) {
      _subscribeCards();
    } else {
      DeferredWarmup.schedule(tabIndex, _subscribeCards);
    }
  }

  final UserWalletService _service;
  StreamSubscription<List<WalletCardModel>>? _cardsSub;

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  List<WalletCardModel> _cards = [];
  bool _isLoading = true;
  String? _error;

  List<WalletCardModel> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserWalletService get service => _service;

  void _subscribeCards() {
    _cardsSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _cardsSub = _service.walletCardsStream().listen(
      (list) {
        _cards = list;
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
    _disposed = true;
    _cardsSub?.cancel();
    super.dispose();
  }
}
