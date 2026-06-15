
import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';

class MerchantDashboardData {
  const MerchantDashboardData({
    required this.merchant,
    required this.metrics,
    required this.activeModules,
    required this.moduleActive,
  });

  final Map<String, dynamic> merchant;
  final MerchantDashboardMetrics metrics;
  final int activeModules;
  final Map<String, bool> moduleActive;
}

class MerchantDashboardMetrics {
  const MerchantDashboardMetrics({
    required this.customers,
    required this.feedPosts,
    required this.stampCards,
    required this.activeModules,
  });

  final int customers;
  final int feedPosts;
  final int stampCards;
  final int activeModules;
}

class MerchantDashboardService {
  const MerchantDashboardService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  Future<MerchantDashboardData?> loadDashboard() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return null;

    final merchant = await firestoreService.getMerchantProfile(uid);
    if (merchant == null) return null;

    // Zähl-Aufrufe + Modul-Status parallel statt sequenziell laden (#7).
    final countsFuture = Future.wait([
      _count(FirebasePaths.merchantCustomers(uid)),
      _count(FirebasePaths.merchantFeedPosts(uid)),
      _count(FirebasePaths.merchantStampCards(uid)),
    ]);
    final modulesFuture = _moduleStatuses(uid);
    final counts = await countsFuture;
    final customers = counts[0];
    final feedPosts = counts[1];
    final stampCards = counts[2];
    final moduleActive = {
      'feedPosts': true,
      ...await modulesFuture,
    };
    final activeModules = moduleActive.values.where((active) => active).length;

    return MerchantDashboardData(
      merchant: {...merchant, 'merchantId': merchant['merchantId'] ?? uid},
      metrics: MerchantDashboardMetrics(
        customers: customers,
        feedPosts: feedPosts,
        stampCards: stampCards,
        activeModules: activeModules,
      ),
      activeModules: activeModules,
      moduleActive: moduleActive,
    );
  }

  Future<int> _count(String collectionPath) async {
    try {
      // Exakte Server-Aggregation: 1 Read statt bis zu 200, keine 200er-Kappung
      // mehr → korrekte Geschäftszahlen (#7).
      final snapshot =
          await firestoreService.collection(collectionPath).count().get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, bool>> _moduleStatuses(String merchantId) async {
    try {
      final snapshot = await firestoreService
          .collection(FirebasePaths.merchantFeatureConfigs(merchantId))
          .get();
      final states = <String, bool>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final active = _featureActive(data);
        states[doc.id] = active;
        if (doc.id == 'menuCatalog') {
          final settings = data['settings'];
          if (settings is Map) {
            states['catalogOrderQrCashier'] = active && settings['catalogOrderQrCashier'] == true;
            states['catalogOrderSendCashier'] = active && settings['catalogOrderSendCashier'] == true;
            states['catalogTableOrders'] = active && settings['catalogTableOrders'] == true;
          }
        }
      }
      return states;
    } catch (_) {
      return const {};
    }
  }

  bool _featureActive(Map<String, dynamic> data) {
    final status = data['status']?.toString();
    return data['isEnabled'] == true ||
        data['isActive'] == true ||
        status == 'active' ||
        status == 'enabled';
  }

  Future<void> signOut() => authService.signOut();
}
