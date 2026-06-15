import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/walletCardModel.dart';
import '../services/userWalletService.dart';

class UserWalletProvider extends ChangeNotifier {
  UserWalletProvider({required UserWalletService service})
      : _service = service {
    _subscribeCards();
  }

  final UserWalletService _service;
  StreamSubscription<List<WalletCardModel>>? _cardsSub;

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
    _cardsSub?.cancel();
    super.dispose();
  }
}
