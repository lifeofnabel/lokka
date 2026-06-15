import 'package:flutter/foundation.dart';

import '../models/merchantFeatureModule.dart';
import '../services/merchantFeaturesService.dart';

class MerchantFeaturesProvider extends ChangeNotifier {
  MerchantFeaturesProvider({required this.service});

  final MerchantFeaturesService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  Map<String, bool> states = const {};
  Map<String, bool> draftStates = const {};
  Map<String, Map<String, bool>> settings = const {};
  Map<String, Map<String, bool>> draftSettings = const {};

  bool get hasChanges => !_sameBoolMap(states, draftStates) || !_sameNestedMap(settings, draftSettings);

  bool isEnabled(MerchantFeatureModule module) {
    return module.isRequired || (draftStates[module.key] ?? false);
  }

  bool optionEnabled(MerchantFeatureModule module, MerchantFeatureOption option) {
    if (option.key == 'catalogOnly') return isEnabled(module);
    return draftSettings[module.key]?[option.key] ?? false;
  }

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      await service.ensureRequiredFeatures();
      final bundle = await service.loadFeatureStates();
      states = bundle.states;
      draftStates = {...bundle.states};
      settings = _cloneNested(bundle.settings);
      draftSettings = _cloneNested(bundle.settings);
    } catch (e) {
      // Keine rohe Exception an die UI (#20): auf i18n-Key mappen, StateError-Key
      // (z. B. auth.error.signInAgain) erhalten.
      error = e is StateError ? e.message : 'merchant.features.error.load';
      debugPrint('MerchantFeaturesProvider.load failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setEnabled(MerchantFeatureModule module, bool enabled) {
    if (module.isRequired || module.comingSoon) return;
    draftStates = {...draftStates, module.key: enabled};
    notifyListeners();
  }

  void setOptionEnabled(MerchantFeatureModule module, MerchantFeatureOption option, bool enabled) {
    if (module.isRequired || module.comingSoon || option.key == 'catalogOnly') return;
    final current = {...?draftSettings[module.key]};
    current[option.key] = enabled;
    current['catalogOnly'] = true;
    draftSettings = {...draftSettings, module.key: current};
    notifyListeners();
  }

  Future<void> saveChanges() async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();

      // Nur tatsächlich geänderte, nicht-comingSoon-Module schreiben (#19) –
      // in einem atomaren Batch (#21), statt N+1 sequenzielle Writes.
      final changed = merchantFeatureModules.where((module) {
        if (module.comingSoon) return false;
        final stateChanged =
            (states[module.key] ?? false) != (draftStates[module.key] ?? false);
        final settingsChanged = !_sameBoolMap(
          settings[module.key] ?? const {},
          draftSettings[module.key] ?? const {},
        );
        return stateChanged || settingsChanged;
      }).toList();

      if (changed.isNotEmpty) {
        await service.saveFeatureStates(
          changed,
          enabled: draftStates,
          settings: draftSettings,
        );
      }
      states = {...draftStates};
      settings = _cloneNested(draftSettings);
    } catch (e) {
      // Technische Exception NICHT roh an die UI durchreichen (#20): auf einen
      // i18n-Key mappen (StateError trägt bereits einen Key, z. B. die
      // "auth.error.signInAgain"-Meldung aus service.merchantId).
      error = e is StateError ? e.message : 'merchant.features.error.save';
      debugPrint('MerchantFeaturesProvider.saveChanges failed: $e');
      // Recovery-Reload separat absichern, damit ein zweiter Fehler nicht
      // unbehandelt durchschlägt (#21).
      try {
        final bundle = await service.loadFeatureStates();
        states = bundle.states;
        draftStates = {...bundle.states};
        settings = _cloneNested(bundle.settings);
        draftSettings = _cloneNested(bundle.settings);
      } catch (reloadError) {
        debugPrint(
          'MerchantFeaturesProvider.saveChanges recovery reload failed: $reloadError',
        );
      }
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

Map<String, Map<String, bool>> _cloneNested(Map<String, Map<String, bool>> value) {
  return {
    for (final entry in value.entries) entry.key: {...entry.value},
  };
}

bool _sameBoolMap(Map<String, bool> a, Map<String, bool> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _sameNestedMap(Map<String, Map<String, bool>> a, Map<String, Map<String, bool>> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || !_sameBoolMap(entry.value, other)) return false;
  }
  return true;
}
