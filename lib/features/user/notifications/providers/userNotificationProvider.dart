import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lokka/core/utils/deferredWarmup.dart';
import 'package:lokka/features/user/notifications/models/userNotificationModel.dart';
import 'package:lokka/features/user/notifications/services/userNotificationService.dart';

class UserNotificationProvider extends ChangeNotifier {
  /// [tabIndex] lässt den Start verzögern, solange ein anderer Tab aktiv ist
  /// (siehe [DeferredWarmup]) – null startet sofort (Default/Testverhalten).
  UserNotificationProvider({required UserNotificationService service, int? tabIndex})
      : _service = service {
    void start() {
      _subscribe();
      // Best-effort Nudges beim Start (kostenlos, ohne Server).
      unawaited(_service.generateNudges());
    }

    if (tabIndex == null) {
      start();
    } else {
      DeferredWarmup.schedule(tabIndex, start);
    }
  }

  final UserNotificationService _service;
  StreamSubscription<List<UserNotificationModel>>? _sub;

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

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
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
