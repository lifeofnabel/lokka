import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../models/feedAiSuggestionModel.dart';
import '../models/feedCatalogItem.dart';
import 'feedAiSuggestionService.dart';

class MerchantFeedCreateService {
  const MerchantFeedCreateService({
    required this.authService,
    required this.firestoreService,
    required this.aiSuggestionService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;
  final FeedAiSuggestionService aiSuggestionService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('auth.error.signInAgain');
    return uid;
  }

  Future<Map<String, dynamic>> loadMerchant() async {
    return await firestoreService.getMerchantProfile(merchantId) ?? const {};
  }

  Future<List<Map<String, dynamic>>> loadCategories() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItemCategories(merchantId))
        .get();
    final categories = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((data) => data['isArchived'] != true && data['isPrivate'] != true)
        .toList();
    categories.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return categories;
  }

  Future<List<FeedCatalogItem>> loadItems() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItems(merchantId))
        .get();
    final items = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((data) => data['isArchived'] != true)
        .map(FeedCatalogItem.fromMap)
        .toList();
    items.sort((a, b) => a.displayName.compareTo(b.displayName));
    return items;
  }

  Future<int> aiUsesToday() async {
    final data = await firestoreService.readDocument(
      FirebasePaths.aiUsageEntry(_aiUsageId()),
    );
    return (data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<FeedAiSuggestionModel> suggestPost({
    required String type,
    required String input,
  }) async {
    final count = await aiUsesToday();
    if (count >= 5) {
      throw StateError('merchant.feedCreate.aiLimitReached');
    }
    final merchant = await loadMerchant();
    final categories = await loadCategories();
    final items = await loadItems();
    final suggestion = await aiSuggestionService.suggest(
      merchantId: merchantId,
      type: type,
      input: input,
      merchant: merchant,
      categories: categories,
      items: items.map((item) => item.toRuleMap()).toList(),
    );
    await firestoreService.setDocument(
      FirebasePaths.aiUsageEntry(_aiUsageId()),
      {
        'usageId': _aiUsageId(),
        'merchantId': merchantId,
        'dateKey': _dayKey(),
        'count': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    return suggestion;
  }

  /// Reine Text-Korrektur der drei Basisfelder über das KI-Endpoint.
  /// Zählt KEINE KI-Nutzung hoch – das Tageslimit für die Korrektur wird
  /// im Provider lokal (LocalCacheService) verwaltet.
  Future<FeedAiSuggestionModel> correctFields({
    required String type,
    required String title,
    required String subtitle,
    required String description,
  }) async {
    final merchant = await loadMerchant();
    return aiSuggestionService.correctFields(
      merchantId: merchantId,
      type: type,
      title: title,
      subtitle: subtitle,
      description: description,
      merchant: merchant,
    );
  }

  Future<void> createPost({
    required String type,
    required String title,
    required String subtitle,
    required String description,
    required String imageUrl,
    String ctaLabel = '',
    String ctaType = '',
    String ctaLinkType = '',
    String ctaTargetId = '',
    String ctaUrl = '',
    String linkedCardId = '',
    String targetAudience = 'all',
    Map<String, dynamic> rules = const {},
    DateTime? startsAt,
    DateTime? endsAt,
    bool isPrivate = false,
  }) async {
    final merchant = await loadMerchant();
    final postId = firestoreService.collection(FirebasePaths.feed).doc().id;
    final now = DateTime.now();
    final isScheduled = startsAt != null && startsAt.isAfter(now);
    final ctaRoute = ctaRouteFor(
      merchantId: merchantId,
      linkType: ctaLinkType,
      targetId: ctaTargetId,
    );
    final data = {
      'postId': postId,
      'merchantId': merchantId,
      'merchantName': merchant['shopName'] ?? merchant['businessName'] ?? '',
      'merchantLogoUrl': merchant['logoUrl'] ?? '',
      'merchantCity': merchant['city'] ?? '',
      'merchantShopType': merchant['shopType'] ?? merchant['shopTypePrimary'] ?? '',
      'type': type,
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl.trim(),
      'imageAspectRatio': 1,
      'oldPrice': rules['oldPrice'],
      'newPrice': rules['newPrice'],
      'discountPercent': rules['discountPercent'],
      'linkedItemIds': rules['linkedItemIds'] ?? const [],
      'linkedItems': rules['linkedItems'] ?? const [],
      'ctaLabel': ctaLabel.trim(),
      'ctaType': ctaType.trim(),
      'ctaLinkType': ctaLinkType.trim(),
      'ctaTargetId': ctaTargetId.trim(),
      'ctaUrl': ctaUrl.trim(),
      'ctaRoute': ctaRoute,
      'linkedCardId': linkedCardId.trim(),
      'targetAudience': targetAudience.trim().isEmpty ? 'all' : targetAudience.trim(),
      'rules': rules,
      'startDate': startsAt == null ? null : Timestamp.fromDate(startsAt),
      'scheduledAt': startsAt == null ? null : Timestamp.fromDate(startsAt),
      'endDate': endsAt == null ? null : Timestamp.fromDate(endsAt),
      'isScheduled': isScheduled,
      'isActive': !isScheduled,
      'isArchived': false,
      'isPrivate': isPrivate,
      'likesCount': 0,
      'viewsCount': 0,
      'opensCount': 0,
      'clicksCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'publishedAt': isScheduled ? null : FieldValue.serverTimestamp(),
    };
    final batch = firestoreService.batch();
    batch.set(firestoreService.document(FirebasePaths.merchantFeedPost(merchantId, postId)), data);
    batch.set(firestoreService.document(FirebasePaths.feedPost(postId)), data);
    await batch.commit();
  }

  /// Resolves the in-app deep link a CTA target maps to. Static + shared so the
  /// per-post CTA editor and the create flow compute the route identically.
  ///
  /// Targets: 'profile' → merchant page, 'url' → external (no route), 'stampCard'
  /// → that merchant's wallet cards. Legacy 'shop'/'catalog'/'feedPost' kept.
  static String ctaRouteFor({
    required String merchantId,
    required String linkType,
    required String targetId,
  }) {
    return switch (linkType) {
      'profile' => '/user/partners/$merchantId',
      'stampCard' => '/user/stamps/$merchantId',
      'shop' => '/shop/$merchantId',
      'catalog' => '/shop/$merchantId',
      'feedPost' =>
        targetId.trim().isEmpty ? '' : '/user/feed/${targetId.trim()}',
      _ => '',
    };
  }

  String _aiUsageId() => '${merchantId}_${_dayKey()}';

  String _dayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}$month$day';
  }
}
