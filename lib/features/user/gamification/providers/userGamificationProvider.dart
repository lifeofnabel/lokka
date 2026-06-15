import 'package:flutter/foundation.dart';
import 'package:lokka/features/user/gamification/models/gamificationModel.dart';
import 'package:lokka/features/user/gamification/services/userGamificationService.dart';

class UserGamificationProvider extends ChangeNotifier {
  UserGamificationProvider({required UserGamificationService service})
      : _service = service {
    reload();
  }

  final UserGamificationService _service;
  GamificationStats _stats = GamificationStats.empty;
  bool _isLoading = true;

  GamificationStats get stats => _stats;
  bool get isLoading => _isLoading;
  UserGamificationService get service => _service;

  Future<void> reload() async {
    try {
      _stats = await _service.loadStats();
    } catch (_) {
      // best-effort — Gamification darf nie blockieren
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
