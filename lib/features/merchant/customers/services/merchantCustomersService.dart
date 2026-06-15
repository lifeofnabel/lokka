import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../models/merchantCustomerModel.dart';

class MerchantCustomersService {
  const MerchantCustomersService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  /// Obergrenze pro Laden – verhindert unbeschränkte Reads auf der (am
  /// stärksten wachsenden) Kunden-Collection (#28). Kein server-seitiges
  /// orderBy, da das Zeitfeld (lastVisitAt/lastSeenAt/updatedAt) nicht garantiert
  /// gesetzt ist und sonst Kunden ausgeblendet würden; Sortierung bleibt clientseitig.
  static const int customersPageLimit = 200;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('auth.error.signInAgain');
    return uid;
  }

  Future<List<MerchantCustomerModel>> loadCustomers() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantCustomers(merchantId))
        .limit(customersPageLimit)
        .get();
    final customers = snapshot.docs
        .map((doc) => MerchantCustomerModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
    customers.sort((a, b) {
      final aDate = a.lastVisitAt ?? DateTime(0);
      final bDate = b.lastVisitAt ?? DateTime(0);
      return bDate.compareTo(aDate);
    });
    return customers;
  }
}
