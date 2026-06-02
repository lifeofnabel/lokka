import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';

class MerchantDashboardData {
  const MerchantDashboardData({
    required this.merchant,
    required this.metrics,
    required this.activeModules,
    required this.weekCredits,
    required this.hasBillingData,
    required this.moduleActive,
  });

  final Map<String, dynamic> merchant;
  final MerchantDashboardMetrics metrics;
  final int activeModules;
  final int weekCredits;
  final bool hasBillingData;
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

    final customers = await _count(FirebasePaths.merchantCustomers(uid));
    final feedPosts = await _count(FirebasePaths.merchantFeedPosts(uid));
    final stampCards = await _count(FirebasePaths.merchantStampCards(uid));
    final moduleActive = {
      'feedPosts': true,
      ...await _moduleStatuses(uid),
    };
    final activeModules = moduleActive.values.where((active) => active).length;
    final billing = await _weekCredits(uid);

    return MerchantDashboardData(
      merchant: {...merchant, 'merchantId': merchant['merchantId'] ?? uid},
      metrics: MerchantDashboardMetrics(
        customers: customers,
        feedPosts: feedPosts,
        stampCards: stampCards,
        activeModules: activeModules,
      ),
      activeModules: activeModules,
      weekCredits: billing.$1,
      hasBillingData: billing.$2,
      moduleActive: moduleActive,
    );
  }

  Future<int> _count(String collectionPath) async {
    try {
      final snapshot =
          await firestoreService.collection(collectionPath).limit(200).get();
      return snapshot.docs.length;
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

  Future<(int, bool)> _weekCredits(String merchantId) async {
    try {
      final snapshot = await firestoreService
          .collection(FirebasePaths.merchantBillingWeeks(merchantId))
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return (0, false);
      final data = snapshot.docs.first.data();
      final value = data['credits'] ?? data['totalCredits'] ?? data['creditsUsed'] ?? 0;
      return ((value as num?)?.toInt() ?? 0, true);
    } catch (_) {
      return (0, false);
    }
  }

  Future<void> signOut() => authService.signOut();
}
