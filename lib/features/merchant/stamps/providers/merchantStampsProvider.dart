import 'package:flutter/foundation.dart';

import '../../../../core/services/uploadService.dart';
import '../../../stamps/services/stampFunctionsService.dart';
import '../../catalog/models/merchantItemData.dart';
import '../models/stampCardModel.dart';
import '../services/merchantStampsService.dart';

class MerchantStampsProvider extends ChangeNotifier {
  MerchantStampsProvider({
    required this.service,
    required this.uploadService,
    StampFunctionsService? functions,
  }) : functions = functions ?? StampFunctionsService();

  final MerchantStampsService service;
  final UploadService uploadService;
  final StampFunctionsService functions;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<StampCardModel> cards = [];
  List<MerchantItemData> items = [];
  StampCardModel? editingCard;

  String get merchantId => service.merchantId;

  Future<void> load({String? editId}) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      cards = await service.loadStampCards();
      items = await service.loadItems();
      if (editId != null && editId.isNotEmpty) {
        editingCard = null;
        for (final card in cards) {
          if (card.id == editId) {
            editingCard = card;
            break;
          }
        }
        editingCard ??= await service.loadStampCard(editId);
      } else {
        editingCard = StampCardModel.empty(merchantId: merchantId);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setError(String message) {
    error = message;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<String?> uploadImage({required UploadImageType type}) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final media = await uploadService.pickAndUploadOptimizedImage(type: type);
      return media?.secureUrl.isNotEmpty == true ? media!.secureUrl : media?.url;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> saveCard(StampCardModel card) async {
    return _saving(() => service.saveCard(card));
  }

  Future<String?> publishCard(StampCardModel card) async {
    final id = await _saving(() => service.publishCard(card));
    return id;
  }

  /// Sets the cooldown (Wartezeit) and the optional supply cap
  /// (Verfügbare Anzahl) in one merge write, preserving every other field.
  Future<void> setLimits(
    StampCardModel card, {
    required int cooldownSeconds,
    required int? maxDistribution,
  }) async {
    await _savingVoid(() => service.setLimits(
          card.id,
          claimLimits: {...card.claimLimits, 'cooldownSeconds': cooldownSeconds},
          maxDistribution: maxDistribution,
        ));
    await load();
  }

  Future<void> pauseCard(String stampCardId) async {
    await _savingVoid(() => service.pauseCard(stampCardId));
    await load();
  }

  Future<void> archiveCard(String stampCardId) async {
    await _savingVoid(() => service.archiveCard(stampCardId));
    await load();
  }

  Future<void> deleteDraftCard(String stampCardId) async {
    await _savingVoid(() => service.deleteDraftCard(stampCardId));
    await load();
  }

  Future<void> duplicateCard(StampCardModel card) async {
    await _savingVoid(() => service.duplicateCard(card));
    await load();
  }

  /// Cards that count against the 3-card limit (everything except archived).
  int get activeCount => cards.where((c) => !c.isArchivedCard).length;
  static const int maxActiveCards = 3;
  bool get atCap => activeCount >= maxActiveCards;

  /// Live cards a physical stick can be bound to.
  List<StampCardModel> get liveCards =>
      cards.where((c) => c.isLive).toList(growable: false);

  Future<String?> _saving(Future<String> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final id = await action();
      // Performance (#69): kein kompletter load() mehr nach jedem Save/Publish.
      // Nur die geänderte Karte gezielt nachladen (ein get()) und die bereits
      // gecachte Liste/Items in-memory aktualisieren – spart die doppelten
      // Collection- und Items-Reads.
      await _refreshCard(id);
      return id;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Lädt eine einzelne Karte neu und führt sie in den vorhandenen Cache zusammen
  /// (Liste + editingCard), ohne Items oder die gesamte Collection erneut zu lesen.
  Future<void> _refreshCard(String id) async {
    final updated = await service.loadStampCard(id);
    if (updated == null) return;
    editingCard = updated;
    final index = cards.indexWhere((card) => card.id == id);
    if (index >= 0) {
      cards[index] = updated;
    } else {
      cards = [updated, ...cards];
    }
  }

  Future<void> _savingVoid(Future<void> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
