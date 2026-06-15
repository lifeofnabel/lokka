import 'package:flutter/foundation.dart';

import '../../../../core/models/menuDesign.dart';
import '../services/merchantMenuSettingsService.dart';

enum MenuSaveResult { success, missingUrl, error }

/// State + Logik der Speisekarten-Einstellungen (Shell/Provider-Muster, #42).
/// Firestore-Zugriffe liegen im Service.
class MerchantMenuSettingsProvider extends ChangeNotifier {
  MerchantMenuSettingsProvider({required this.service});

  final MerchantMenuSettingsService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  String externalUrl = '';
  bool externalEnabled = false;
  bool integratedEnabled = false;

  /// Gestaltung der Kundenkarte (Vorlage, Farbe, Theme, Spalten).
  MenuDesign style = const MenuDesign();

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final data = await service.load();
      externalUrl = data.externalUrl;
      externalEnabled = data.externalEnabled;
      integratedEnabled = data.integratedEnabled;
      style = data.style;
    } catch (e) {
      // Technische Exception auf i18n-Key mappen; StateError trägt schon einen.
      error = e is StateError ? e.message : 'merchant.menu.error.load';
      debugPrint('MerchantMenuSettingsProvider.load failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setExternalEnabled(bool value) {
    externalEnabled = value;
    notifyListeners();
  }

  void setIntegratedEnabled(bool value) {
    integratedEnabled = value;
    notifyListeners();
  }

  void setLayout(MenuLayoutStyle layout) {
    style = style.copyWith(layout: layout);
    notifyListeners();
  }

  void setAccentColor(int accentColor) {
    style = style.copyWith(accentColor: accentColor);
    notifyListeners();
  }

  void setDarkMode(bool value) {
    style = style.copyWith(darkMode: value);
    notifyListeners();
  }

  void setColumns(int columns) {
    style = style.copyWith(columns: columns);
    notifyListeners();
  }

  Future<MenuSaveResult> save({required String url}) async {
    final trimmed = url.trim();
    if (externalEnabled && trimmed.isEmpty) return MenuSaveResult.missingUrl;
    try {
      isSaving = true;
      notifyListeners();
      await service.save(MenuSettingsData(
        externalUrl: trimmed,
        externalEnabled: externalEnabled,
        integratedEnabled: integratedEnabled,
        style: style,
      ));
      externalUrl = trimmed;
      return MenuSaveResult.success;
    } catch (e) {
      debugPrint('MerchantMenuSettingsProvider.save failed: $e');
      return MenuSaveResult.error;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
