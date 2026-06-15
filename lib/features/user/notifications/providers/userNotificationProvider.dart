import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lokka/features/user/notifications/models/userNotificationModel.dart';
import 'package:lokka/features/user/notifications/services/userNotificationService.dart';

class UserNotificationProvider extends ChangeNotifier {
  UserNotificationProvider({required UserNotificationService service})
      : _service = service {
    _subscribe();
    // Best-effort Nudges beim Start (kostenlos, ohne Server).
    unawaited(_service.generateNudges());
  }

  final UserNotificationService _service;
  StreamSubscription<List<UserNotificationModel>>? _sub;

  List<UserNotificationModel> _items = [];
  bool _isLoading = true;

  List<UserNotificationModel> get items => _items;
  bool get isLoading => _isLoading;
  int get unreadCount => _items.where((n) => !n.read).length;
  UserNotificationService get service => _service;

  void _subscribe() {
    _sub = _service.notificationsStream().listen(
      (list) {
        _items = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> markRead(String id) => _service.markRead(id);

  Future<void> markAllRead() =>
      _service.markAllRead(_items.where((n) => !n.read).map((n) => n.id));

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
