import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../models/merchantFeatureModule.dart';

class MerchantFeaturesService {
  const MerchantFeaturesService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('auth.error.signInAgain');
    return uid;
  }

  Future<MerchantFeatureStateBundle> loadFeatureStates() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantFeatureConfigs(merchantId))
        .get();
    final states = {
      for (final module in merchantFeatureModules)
        module.key: module.isRequired,
    };
    final settings = <String, Map<String, bool>>{
      for (final module in merchantFeatureModules)
        if (module.options.isNotEmpty)
          module.key: {
            for (final option in module.options)
              option.key: option.key == 'catalogOnly',
          },
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final module = merchantFeatureModuleByKey(doc.id);
      if (module == null) continue;
      states[doc.id] = module.isRequired ||
          data['isEnabled'] == true ||
          data['status'] == 'enabled' ||
          data['status'] == 'active';
      final rawSettings = data['settings'];
      if (rawSettings is Map && module.options.isNotEmpty) {
        settings[doc.id] = {
          for (final option in module.options)
            option.key: option.key == 'catalogOnly'
                ? true
                : rawSettings[option.key] == true,
        };
      }
    }

    states['feedPosts'] = true;
    return MerchantFeatureStateBundle(states: states, settings: settings);
  }

  Future<void> saveFeatureState({
    required String moduleKey,
    required bool enabled,
    Map<String, bool> settings = const {},
  }) async {
    final module = merchantFeatureModuleByKey(moduleKey);
    if (module == null) return;

    final isEnabled = module.isRequired || enabled;
    final status = module.comingSoon
        ? 'comingSoon'
        : isEnabled
            ? 'enabled'
            : 'disabled';

    await firestoreService.setDocument(
      FirebasePaths.merchantFeatureConfig(merchantId, moduleKey),
      {
        'module': moduleKey,
        'isEnabled': isEnabled,
        'status': status,
        if (settings.isNotEmpty) 'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Schreibt die übergebenen Module in EINEM WriteBatch (atomar – kein
  /// partieller Save mehr, #21). comingSoon-Module werden übersprungen, da ihr
  /// Status fix 'comingSoon' ist und der Nutzer sie nicht ändern kann (#19).
  Future<void> saveFeatureStates(
    Iterable<MerchantFeatureModule> modules, {
    required Map<String, bool> enabled,
    required Map<String, Map<String, bool>> settings,
  }) async {
    final mid = merchantId;
    final batch = firestoreService.batch();
    var count = 0;
    for (final module in modules) {
      if (module.comingSoon) continue;
      final isEnabled = module.isRequired || (enabled[module.key] ?? false);
      final status = isEnabled ? 'enabled' : 'disabled';
      final moduleSettings = settings[module.key] ?? const <String, bool>{};
      batch.set(
        firestoreService.document(
          FirebasePaths.merchantFeatureConfig(mid, module.key),
        ),
        {
          'module': module.key,
          'isEnabled': isEnabled,
          'status': status,
          if (moduleSettings.isNotEmpty) 'settings': moduleSettings,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      count++;
    }
    if (count == 0) return;
    await batch.commit();
  }

  Future<void> ensureRequiredFeatures() {
    return saveFeatureState(moduleKey: 'feedPosts', enabled: true);
  }
}

class MerchantFeatureStateBundle {
  const MerchantFeatureStateBundle({
    required this.states,
    required this.settings,
  });

  final Map<String, bool> states;
  final Map<String, Map<String, bool>> settings;
}
