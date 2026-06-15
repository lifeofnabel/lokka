
import 'package:flutter/foundation.dart';

import '../../../../core/services/localCacheService.dart';
import '../../../../core/services/uploadService.dart';
import '../models/feedAiSuggestionModel.dart';
import '../models/feedCatalogItem.dart';
import '../services/merchantFeedCreateService.dart';

class MerchantFeedCreateProvider extends ChangeNotifier {
  MerchantFeedCreateProvider({
    required this.service,
    required this.uploadService,
    required this.cacheService,
  });

  final MerchantFeedCreateService service;
  final UploadService uploadService;
  final LocalCacheService cacheService;

  /// Max. erlaubte KI-Korrekturen pro Kalendertag.
  static const int aiCorrectionLimit = 2;

  bool isSaving = false;
  bool isSuggesting = false;
  bool isCorrecting = false;
  String? error;
  String? aiHint;
  String imageUrl = '';
  int aiUsesToday = 0;
  int aiCorrectionsToday = 0;
  String merchantName = '';
  String merchantLogoUrl = '';
  String merchantArea = '';
  String merchantShopType = '';
  String merchantRatingText = '';
  List<FeedCatalogItem> catalogItems = const [];

  Future<void> load() async {
    await Future.wait([
      loadAiUsage(),
      loadAiCorrectionUsage(),
      loadMerchantPreview(),
      loadCatalogItems(),
    ]);
  }

  String _correctionCacheKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'merchant.ai.feed.${now.year}-$month-$day';
  }

  Future<void> loadAiCorrectionUsage() async {
    try {
      final cached = await cacheService.readMap(
        _correctionCacheKey(),
        ttl: const Duration(days: 2),
      );
      aiCorrectionsToday = (cached?['count'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {
      aiCorrectionsToday = 0;
    }
  }

  bool get canCorrect => aiCorrectionsToday < aiCorrectionLimit;

  Future<void> loadAiUsage() async {
    try {
      aiUsesToday = await service.aiUsesToday();
      notifyListeners();
    } catch (_) {
      aiUsesToday = 0;
    }
  }

  Future<void> loadCatalogItems() async {
    try {
      catalogItems = await service.loadItems();
      notifyListeners();
    } catch (_) {
      catalogItems = const [];
    }
  }

  Future<void> loadMerchantPreview() async {
    try {
      final merchant = await service.loadMerchant();
      merchantName = (merchant['shopName'] ?? merchant['businessName'] ?? '').toString();
      merchantLogoUrl = (merchant['logoUrl'] ?? '').toString();
      merchantArea = (merchant['area'] ?? '').toString();
      merchantShopType = (merchant['shopTypePrimary'] ?? merchant['shopType'] ?? '').toString();
      final rating = merchant['ratingAverage'] ?? merchant['avgRating'] ?? merchant['averageRating'];
      merchantRatingText = rating is num ? rating.toStringAsFixed(1).replaceAll('.', ',') : '';
      notifyListeners();
    } catch (_) {
      merchantName = '';
      merchantLogoUrl = '';
      merchantArea = '';
      merchantShopType = '';
      merchantRatingText = '';
    }
  }

  Future<PickedUploadFile?> pickFeedImage() {
    return uploadService.pickImageWithFilePicker();
  }

  Future<void> uploadCroppedFeedImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final media = await uploadService.uploadOptimizedImageBytes(
        bytes: bytes,
        fileName: fileName,
        type: UploadImageType.feedPost,
      );
      imageUrl = media.secureUrl.isNotEmpty ? media.secureUrl : media.url;
    } catch (e) {
      error = _readableError(e);
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void useCatalogImage(String imageUrl) {
    final clean = imageUrl.trim();
    if (clean.isEmpty) return;
    this.imageUrl = clean;
    notifyListeners();
  }

  Future<bool> createPost({
    required String type,
    required String title,
    required String subtitle,
    required String description,
    required String requiredMessage,
    String ctaLabel = '',
    String ctaType = '',
    String ctaLinkType = '',
    String ctaTargetId = '',
    String ctaUrl = '',
    String targetAudience = 'all',
    Map<String, dynamic> rules = const {},
    DateTime? startsAt,
    DateTime? endsAt,
    bool isPrivate = false,
  }) async {
    if (title.trim().isEmpty || imageUrl.trim().isEmpty) {
      error = requiredMessage;
      notifyListeners();
      return false;
    }
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await service.createPost(
        type: type,
        title: title,
        subtitle: subtitle,
        description: description,
        imageUrl: imageUrl,
        ctaLabel: ctaLabel,
        ctaType: ctaType,
        ctaLinkType: ctaLinkType,
        ctaTargetId: ctaTargetId,
        ctaUrl: ctaUrl,
        targetAudience: targetAudience,
        rules: rules,
        startsAt: startsAt,
        endsAt: endsAt,
        isPrivate: isPrivate,
      );
      return true;
    } catch (e) {
      error = _readableError(e);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<FeedAiSuggestionModel?> suggestPost({
    required String type,
    required String input,
  }) async {
    if (input.trim().isEmpty) {
      error = 'merchant.feedCreate.aiInputRequired';
      notifyListeners();
      return null;
    }
    try {
      isSuggesting = true;
      error = null;
      notifyListeners();
      final suggestion = await service.suggestPost(type: type, input: input);
      aiUsesToday = await service.aiUsesToday();
      return suggestion;
    } catch (e) {
      error = _readableError(e);
      return null;
    } finally {
      isSuggesting = false;
      notifyListeners();
    }
  }

  /// Korrigiert Titel/Untertitel/Beschreibung über das KI-Endpoint.
  ///
  /// - Limit: max. [aiCorrectionLimit] pro Kalendertag (lokal gezählt).
  /// - Graceful: bei Fehler/leerer Antwort wird [aiHint] gesetzt, die Felder
  ///   bleiben unangetastet und der Zähler wird NICHT erhöht.
  Future<FeedAiSuggestionModel?> correctFields({
    required String type,
    required String title,
    required String subtitle,
    required String description,
  }) async {
    if (title.trim().isEmpty &&
        subtitle.trim().isEmpty &&
        description.trim().isEmpty) {
      aiHint = 'merchant.feedCreate.aiCorrect.empty';
      notifyListeners();
      return null;
    }
    if (!canCorrect) {
      aiHint = 'merchant.feedCreate.aiCorrect.limit';
      notifyListeners();
      return null;
    }
    try {
      isCorrecting = true;
      aiHint = null;
      error = null;
      notifyListeners();
      final corrected = await service.correctFields(
        type: type,
        title: title,
        subtitle: subtitle,
        description: description,
      );
      // Erfolg -> Tageszähler lokal erhöhen.
      aiCorrectionsToday += 1;
      await cacheService.writeMap(
        _correctionCacheKey(),
        {'count': aiCorrectionsToday},
      );
      return corrected;
    } catch (_) {
      // Fehlversuche zählen NICHT. Nur dezenter Hinweis, Felder bleiben.
      aiHint = 'merchant.feedCreate.aiCorrect.failed';
      return null;
    } finally {
      isCorrecting = false;
      notifyListeners();
    }
  }

  void clearAiHint() {
    if (aiHint == null) return;
    aiHint = null;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  String _readableError(Object error) {
    final text = error.toString();
    const badStatePrefix = 'Bad state: ';
    if (text.startsWith(badStatePrefix)) {
      return text.substring(badStatePrefix.length);
    }
    return text;
  }
}
