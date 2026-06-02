import 'package:flutter/foundation.dart';

import '../../../../core/services/uploadService.dart';
import '../../catalog/models/merchantItemData.dart';
import '../models/stampCardModel.dart';
import '../services/merchantStampsService.dart';

class MerchantStampsProvider extends ChangeNotifier {
  MerchantStampsProvider({
    required this.service,
    required this.uploadService,
  });

  final MerchantStampsService service;
  final UploadService uploadService;

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
    return _saving(() => service.publishCard(card));
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

  Future<String?> _saving(Future<String> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final id = await action();
      await load(editId: id);
      return id;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
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
