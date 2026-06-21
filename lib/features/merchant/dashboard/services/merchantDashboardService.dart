
import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';

class MerchantDashboardData {
  const MerchantDashboardData({
    required this.merchant,
    required this.hero,
    required this.metrics,
    required this.moduleActive,
    required this.ordersEnabled,
  });

  final Map<String, dynamic> merchant;
  final MerchantHeroFields hero;
  final MerchantDashboardMetrics metrics;
  final Map<String, bool> moduleActive;

  /// Vorberechnet im Service: Orders-Strip nur sichtbar, wenn Katalog aktiv
  /// und mindestens ein Bestell-Sub-Flag gesetzt ist (#240).
  final bool ordersEnabled;

  /// Aufgelöste merchantId aus dem geladenen Snapshot (#237) – kein erneuter
  /// AuthService-Read in der Page nötig.
  String get merchantId => merchant['merchantId']?.toString() ?? '';
}

/// Typisierte, rein darstellende Hero-Felder (#238/#239).
///
/// Mapping/Parsing der Firestore-Rohdaten passiert hier im Service, die
/// [MerchantHeroCard] bleibt rein darstellend.
class MerchantHeroFields {
  const MerchantHeroFields({
    required this.shopName,
    required this.logoUrl,
    required this.coverUrl,
    required this.typeLine,
    required this.city,
  });

  final String shopName;
  final String logoUrl;
  final String coverUrl;
  final String typeLine;
  final String city;

  factory MerchantHeroFields.fromMerchant(Map<String, dynamic> merchant) {
    String text(String key) => merchant[key]?.toString() ?? '';

    final shopTypes = merchant['shopTypes'];
    final typeLine = shopTypes is Iterable
        ? shopTypes
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .join(', ')
        : text('shopType');

    return MerchantHeroFields(
      shopName: text('shopName'),
      logoUrl: text('logoUrl'),
      coverUrl: text('coverUrl'),
      typeLine: typeLine,
      // Geo-Migration: 'city' bevorzugen, 'area' nur als Legacy-Fallback (#239).
      city: text('city').isNotEmpty ? text('city') : text('area'),
    );
  }
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
    // Nur echte Modul-Ebene zählen, abgeleitete catalog-Sub-Flags ausschließen,
    // damit die 'Module'-Zahl nicht überzählt (#242).
    final activeModules =
        _moduleKeys.where((key) => moduleActive[key] == true).length;

    final resolvedMerchant = {
      ...merchant,
      'merchantId': merchant['merchantId'] ?? uid,
    };

    return MerchantDashboardData(
      merchant: resolvedMerchant,
      hero: MerchantHeroFields.fromMerchant(resolvedMerchant),
      metrics: MerchantDashboardMetrics(
        customers: customers,
        feedPosts: feedPosts,
        stampCards: stampCards,
        activeModules: activeModules,
      ),
      moduleActive: moduleActive,
      ordersEnabled: _ordersEnabled(moduleActive),
    );
  }

  /// Echte Modul-Schlüssel (ohne abgeleitete catalog-Sub-Flags) für die
  /// activeModules-Zählung (#242).
  static const _moduleKeys = [
    'feedPosts',
    'stampCards',
    'pointsSystems',
    'menuCatalog',
  ];

  /// Orders-Strip-Sichtbarkeit – einmalig im Service berechnet (#240).
  bool _ordersEnabled(Map<String, bool> moduleActive) {
    if (moduleActive['menuCatalog'] != true) return false;
    return moduleActive['catalogOrderQrCashier'] == true ||
        moduleActive['catalogOrderSendCashier'] == true ||
        moduleActive['catalogTableOrders'] == true;
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
