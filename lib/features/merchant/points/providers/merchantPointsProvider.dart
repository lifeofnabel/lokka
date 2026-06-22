import 'package:flutter/foundation.dart';

import '../../../../core/services/uploadService.dart';
import '../../catalog/models/merchantItemData.dart';
import '../models/pointsSystemModel.dart';
import '../services/merchantPointsService.dart';

class MerchantPointsProvider extends ChangeNotifier {
  MerchantPointsProvider({
    required this.service,
    required this.uploadService,
  });

  final MerchantPointsService service;
  final UploadService uploadService;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<PointsSystemModel> systems = [];
  List<PointsRewardModel> rewards = [];
  List<MerchantItemData> items = [];
  PointsSystemModel? editingSystem;
  PointsRewardModel? editingReward;

  String get merchantId => service.merchantId;
  PointsSystemModel? get activeSystem {
    for (final system in systems) {
      if (system.isLive) return system;
    }
    return null;
  }

  Future<void> load({String? systemId, String? rewardId}) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      systems = await service.loadSystems();
      rewards = await service.loadRewards();
      items = await service.loadItems();
      if (systemId != null && systemId.isNotEmpty) {
        editingSystem = _findSystem(systemId) ?? await service.loadSystem(systemId);
      } else if (systemId != null) {
        editingSystem = PointsSystemModel.empty(merchantId: merchantId);
      }
      if (rewardId != null && rewardId.isNotEmpty) {
        editingReward = _findReward(rewardId) ?? await service.loadReward(rewardId);
      } else if (rewardId != null) {
        editingReward = PointsRewardModel.empty(merchantId: merchantId);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  /// Übernimmt den gerade gespeicherten Datensatz (inkl. neuer id) als
  /// aktuellen Edit-Stand, damit die Edit-Seite NICHT per pushReplacement neu
  /// gemountet werden muss (kein Verlust des lokalen UI-State, kein Re-Mount).
  void adoptSystem(PointsSystemModel system) {
    editingSystem = system;
    systems = [
      system,
      ...systems.where((existing) => existing.id != system.id),
    ];
    notifyListeners();
  }

  void adoptReward(PointsRewardModel reward) {
    editingReward = reward;
    rewards = [
      reward,
      ...rewards.where((existing) => existing.id != reward.id),
    ];
    notifyListeners();
  }

  Future<String?> uploadRewardImage() async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final media = await uploadService.pickAndUploadOptimizedImage(
        type: UploadImageType.pointsReward,
      );
      return media?.secureUrl.isNotEmpty == true ? media!.secureUrl : media?.url;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> saveSystem(PointsSystemModel system) {
    return _saving(() => service.saveSystem(system));
  }

  Future<String?> publishSystem(PointsSystemModel system) {
    return _saving(() => service.publishSystem(system));
  }

  Future<String?> saveReward(PointsRewardModel reward) {
    return _saving(() => service.saveReward(reward));
  }

  Future<String?> publishReward(PointsRewardModel reward) {
    return _saving(() => service.publishReward(reward));
  }

  Future<void> archiveReward(String rewardId) async {
    await _savingVoid(() => service.archiveReward(rewardId));
    await load();
  }

  PointsSystemModel? _findSystem(String id) {
    for (final system in systems) {
      if (system.id == id) return system;
    }
    return null;
  }

  PointsRewardModel? _findReward(String id) {
    for (final reward in rewards) {
      if (reward.id == id) return reward;
    }
    return null;
  }

  Future<String?> _saving(Future<String> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final id = await action();
      await load();
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
