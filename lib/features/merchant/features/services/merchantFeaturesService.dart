import 'dart:async';

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
    // Bewusst alle Doc-IDs der Collection lesen, aber begrenzt: es kann nie
    // mehr Configs als bekannte Module geben (#59 – Schutz gegen unbeabsichtigt
    // unbeschränktes get()).
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantFeatureConfigs(merchantId))
        .limit(merchantFeatureModules.length)
        .get();
    final states = {
      for (final module in merchantFeatureModules)
        module.key: module.isRequired,
    };
    // catalogOnly wird bewusst NICHT in den Settings geführt – es ist kein
    // persistierter Schalter, sondern wird in der UI aus isEnabled abgeleitet
    // (#59). Sonst meldete hasChanges bei jedem Laden falsche Änderungen.
    final settings = <String, Map<String, bool>>{
      for (final module in merchantFeatureModules)
        if (module.options.isNotEmpty)
          module.key: {
            for (final option in module.options)
              if (option.key != 'catalogOnly') option.key: false,
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
            if (option.key != 'catalogOnly')
              option.key: rawSettings[option.key] == true,
        };
      }
    }

    states['feedPosts'] = true;

    // Selbstheilung für Alt-Merchants, die vor dem feedPosts-Write in
    // createMerchantProfile registriert wurden: nur schreiben, wenn das Doc
    // fehlt (#59 – kein redundanter Write bei jedem Seitenaufruf). Bewusst
    // „fire and forget", da der Zustand im Speicher ohnehin feedPosts=true ist.
    final hasFeedDoc = snapshot.docs.any((doc) => doc.id == 'feedPosts');
    if (!hasFeedDoc) {
      unawaited(saveFeatureState(moduleKey: 'feedPosts', enabled: true));
    }

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
        // settings IMMER schreiben (auch leer): bei merge:true kann ein
        // ausgelassenes Feld nicht zurückgesetzt werden (#59). Nur für Module
        // ohne Optionen weglassen, damit dort kein leeres Map-Feld entsteht.
        if (module.options.isNotEmpty) 'settings': settings,
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
          // settings IMMER schreiben (auch leer) für Module mit Optionen, damit
          // ein abgewählter Modus bei merge:true wirklich verschwindet (#59).
          if (module.options.isNotEmpty) 'settings': moduleSettings,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      count++;
    }
    if (count == 0) return;
    await batch.commit();
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
