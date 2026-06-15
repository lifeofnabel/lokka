import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/merchant/points/models/pointsSystemModel.dart';
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';

/// Zusammenfassung der aktiven Treue-Programme eines Partners.
class LoyaltyInfo {
  const LoyaltyInfo({
    required this.hasPoints,
    required this.hasStamps,
    this.activePointsSystems = 0,
    this.activeStampCards = 0,
  });

  /// Mindestens ein aktives Punktesystem vorhanden.
  final bool hasPoints;

  /// Mindestens eine aktive Stempelkarte vorhanden.
  final bool hasStamps;

  final int activePointsSystems;
  final int activeStampCards;

  bool get hasAny => hasPoints || hasStamps;

  static const none = LoyaltyInfo(hasPoints: false, hasStamps: false);
}

/// Liest die Treue-Programme eines Partners aus User-Sicht (read-only).
///
/// Quelle sind die bestehenden Merchant-Subcollections
/// (`merchants/{id}/pointsSystems`, `merchants/{id}/pointsRewards`,
/// `merchants/{id}/stampCards`). Gefiltert wird client-seitig auf
/// AKTIVE Einträge (status == 'active', isActive == true, nicht archiviert),
/// damit keine Firestore-Composite-Indizes nötig sind.
class UserLoyaltyService {
  UserLoyaltyService({required FirestoreService firestoreService})
      : _firestore = firestoreService;

  final FirestoreService _firestore;

  /// Zählt aktive Punktesysteme und Stempelkarten eines Partners.
  Future<LoyaltyInfo> fetchLoyaltyInfo(String merchantId) async {
    final pointsFuture = fetchPointsSystems(merchantId);
    final stampsFuture = fetchStampCards(merchantId);
    final pointsSystems = await pointsFuture;
    final stampCards = await stampsFuture;
    return LoyaltyInfo(
      hasPoints: pointsSystems.isNotEmpty,
      hasStamps: stampCards.isNotEmpty,
      activePointsSystems: pointsSystems.length,
      activeStampCards: stampCards.length,
    );
  }

  /// Aktive Punktesysteme (`merchants/{id}/pointsSystems`).
  Future<List<PointsSystemModel>> fetchPointsSystems(String merchantId) async {
    final snap = await _firestore
        .collection(FirebasePaths.merchantPointsSystems(merchantId))
        .get();
    return snap.docs
        .map((doc) => PointsSystemModel.fromMap(
            {...doc.data(), 'id': doc.data()['id'] ?? doc.id}))
        .where((system) => system.isLive && !system.isArchivedSystem)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Aktive Punkte-Geschenke (`merchants/{id}/pointsRewards`),
  /// aufsteigend nach benötigten Punkten sortiert.
  Future<List<PointsRewardModel>> fetchPointsRewards(String merchantId) async {
    final snap = await _firestore
        .collection(FirebasePaths.merchantPointsRewards(merchantId))
        .get();
    return snap.docs
        .map((doc) => PointsRewardModel.fromMap(
            {...doc.data(), 'id': doc.data()['id'] ?? doc.id}))
        .where((reward) => reward.isLive && !reward.isArchivedReward)
        .toList()
      ..sort((a, b) => a.requiredPoints.compareTo(b.requiredPoints));
  }

  /// Aktive Stempelkarten (`merchants/{id}/stampCards`).
  Future<List<StampCardModel>> fetchStampCards(String merchantId) async {
    final snap = await _firestore
        .collection(FirebasePaths.merchantStampCards(merchantId))
        .get();
    return snap.docs
        .map((doc) => StampCardModel.fromMap(
            {...doc.data(), 'id': doc.data()['id'] ?? doc.id}))
        .where((card) => card.isLive && !card.isArchivedCard)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}
