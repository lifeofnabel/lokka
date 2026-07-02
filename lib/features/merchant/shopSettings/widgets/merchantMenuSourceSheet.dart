import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../features/services/merchantFeaturesService.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantMenuSettingsService.dart';

/// Speisekarten-Quellen als kompaktes Popout (statt eigener Seite):
/// ⭐ Lokka-Karte (Empfohlen) · 🔗 Eigener Link · 📄 PDF.
/// Änderungen speichern SOFORT (kein Speichern-Button). Erklärungen stecken
/// in ⓘ-Tooltips statt Text-Absätzen. Ist die Katalog-Funktion aus, zeigt das
/// Sheet einen Hinweis + 1-Tap-Aktivierung, statt ins Leere zu laufen.
/// Die Seite `/merchant/menu` bleibt als Deep-Link-Alias bestehen.
Future<void> showMenuSourceSheet(BuildContext context) {
  final auth = context.read<AuthService>();
  final firestore = context.read<FirestoreService>();
  final menuService = MerchantMenuSettingsService(
    authService: auth,
    firestoreService: firestore,
  );
  final featuresService = MerchantFeaturesService(
    authService: auth,
    firestoreService: firestore,
  );
  final uploadService = context.read<UploadService>();
  final texts = context.read<LanguageService>();
  final merchantId = auth.currentUser?.uid ?? '';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => Provider<LanguageService>.value(
      value: texts,
      child: _MenuSourceSheet(
        menuService: menuService,
        featuresService: featuresService,
        uploadService: uploadService,
        firestoreService: firestore,
        merchantId: merchantId,
      ),
    ),
  );
}

class _MenuSourceSheet extends StatefulWidget {
  const _MenuSourceSheet({
    required this.menuService,
    required this.featuresService,
    required this.uploadService,
    required this.firestoreService,
    required this.merchantId,
  });

  final MerchantMenuSettingsService menuService;
  final MerchantFeaturesService featuresService;
  final UploadService uploadService;
  final FirestoreService firestoreService;
  final String merchantId;

  @override
  State<_MenuSourceSheet> createState() => _MenuSourceSheetState();
}

class _MenuSourceSheetState extends State<_MenuSourceSheet> {
  final _urlCtrl = TextEditingController();

  bool _loading = true;
  bool _loadFailed = false;
  bool _catalogEnabled = true;
  bool _activatingCatalog = false;
  MenuSettingsData _settings = const MenuSettingsData(
    externalUrl: '',
    externalEnabled: false,
    integratedEnabled: false,
  );
  bool _saving = false;
  bool _uploadingPdf = false;

  /// Link-Details erst nach Tap auf die Option ausklappen (weniger Wand).
  bool _linkExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.menuService.load(),
        widget.firestoreService.readDocument(
          FirebasePaths.merchantFeatureConfig(widget.merchantId, 'menuCatalog'),
        ),
      ]);
      final settings = results[0] as MenuSettingsData;
      final config = results[1] as Map<String, dynamic>?;
      final catalogOn = config?['isEnabled'] == true ||
          config?['status'] == 'enabled' ||
          config?['status'] == 'active';
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _catalogEnabled = catalogOn;
        _urlCtrl.text = settings.externalUrl;
        _linkExpanded = settings.externalEnabled;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// Persistiert den aktuellen Stand sofort. Externer Link wird nur als
  /// aktiv gespeichert, wenn auch eine URL da ist (kein kaputter Zustand).
  Future<void> _persist({
    bool? integrated,
    bool? externalEnabled,
    String? externalUrl,
  }) async {
    final texts = context.read<LanguageService>();
    final next = MenuSettingsData(
      externalUrl: (externalUrl ?? _settings.externalUrl).trim(),
      externalEnabled: (externalEnabled ?? _settings.externalEnabled) &&
          (externalUrl ?? _settings.externalUrl).trim().isNotEmpty,
      integratedEnabled: integrated ?? _settings.integratedEnabled,
      style: _settings.style,
    );
    setState(() {
      _settings = next;
      _saving = true;
    });
    try {
      await widget.menuService.save(next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(texts.text('merchant.menu.error.save'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _activateCatalog() async {
    final texts = context.read<LanguageService>();
    setState(() => _activatingCatalog = true);
    try {
      // Nur einschalten – ohne Modus fällt die Kundenkarte automatisch auf
      // „Nur Speisekarte" zurück (PublicShopService.loadCatalogConfig), was
      // hier genau die richtige Vorgabe ist. Bestell-Modi wählt der Merchant
      // später unter „Funktionen".
      await widget.featuresService
          .saveFeatureState(moduleKey: 'menuCatalog', enabled: true);
      if (!mounted) return;
      setState(() => _catalogEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texts.text('merchant.menu.catalogActivated'))),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(texts.text('merchant.menu.error.save'))),
        );
      }
    } finally {
      if (mounted) setState(() => _activatingCatalog = false);
    }
  }

  Future<void> _applyLink() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await _persist(externalEnabled: true, externalUrl: url);
  }

  Future<void> _uploadPdf() async {
    final texts = context.read<LanguageService>();
    setState(() => _uploadingPdf = true);
    try {
      final url = await widget.uploadService.pickAndUploadMenuPdf();
      if (url == null || !mounted) return; // abgebrochen
      _urlCtrl.text = url;
      await _persist(externalEnabled: true, externalUrl: url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(texts.text('merchant.menu.pdfUploaded'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(texts.text('merchant.menu.error.pdfUpload'))));
      }
    } finally {
      if (mounted) setState(() => _uploadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                      color: MerchantPremiumColors.gold),
                ),
              )
            : _loadFailed
                ? _LoadError(onRetry: () {
                    setState(() {
                      _loading = true;
                      _loadFailed = false;
                    });
                    _load();
                  })
                : _content(texts),
      ),
    );
  }

  Widget _content(LanguageService texts) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                texts.text('merchant.menu.title'),
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (_saving)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: MerchantPremiumColors.gold),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Katalog aus → Lokka-Karte wäre leer. Hinweis + 1-Tap-Aktivierung.
        if (!_catalogEnabled) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MerchantPremiumColors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: MerchantPremiumColors.warning),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts.text('merchant.menu.catalogOffTitle'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _activatingCatalog ? null : _activateCatalog,
                  icon: _activatingCatalog
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.power_settings_new_rounded, size: 18),
                  label: Text(texts.text('merchant.menu.activateCatalog')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MerchantPremiumColors.ink,
                    side: const BorderSide(color: MerchantPremiumColors.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ⭐ Lokka-Karte (Empfohlen)
        _OptionRow(
          icon: Icons.restaurant_menu_rounded,
          title: texts.text('merchant.menu.lokkaShort'),
          badge: texts.text('merchant.menu.recommended'),
          tooltip: texts.text('merchant.menu.lokkaTip'),
          enabled: _catalogEnabled,
          value: _settings.integratedEnabled && _catalogEnabled,
          onChanged: (v) => _persist(integrated: v),
        ),
        if (_settings.integratedEnabled && _catalogEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: TextButton.icon(
              onPressed: () {
                // Router VOR dem pop greifen – danach ist der Sheet-Context
                // deaktiviert und context.push würde crashen.
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push('/merchant/catalog');
              },
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: Text(texts.text('merchant.menu.openCatalog')),
              style: TextButton.styleFrom(
                foregroundColor: MerchantPremiumColors.muted,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),

        // 🔗 Eigener Link / 📄 PDF
        _OptionRow(
          icon: Icons.link_rounded,
          title: texts.text('merchant.menu.linkShort'),
          tooltip: texts.text('merchant.menu.linkTip'),
          enabled: true,
          value: _settings.externalEnabled,
          onChanged: (v) {
            if (v) {
              setState(() => _linkExpanded = true);
              if (_urlCtrl.text.trim().isNotEmpty) {
                // URL ist schon da (früher gespeichert) → direkt aktivieren.
                _persist(externalEnabled: true, externalUrl: _urlCtrl.text);
              }
              // Ohne URL: nur ausklappen – aktiv wird erst mit URL/PDF
              // gespeichert (kein kaputter „an ohne Ziel"-Zustand).
            } else {
              setState(() => _linkExpanded = false);
              _persist(externalEnabled: false);
            }
          },
        ),
        if (_linkExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _applyLink(),
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: texts.text('merchant.menu.urlHint'),
                    hintStyle: TextStyle(
                        color:
                            MerchantPremiumColors.muted.withValues(alpha: 0.8)),
                    filled: true,
                    fillColor: MerchantPremiumColors.surfaceAlt,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      tooltip: texts.text('merchant.menu.applyLink'),
                      onPressed: _applyLink,
                      icon: const Icon(Icons.check_rounded,
                          color: MerchantPremiumColors.gold),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _uploadingPdf ? null : _uploadPdf,
                  icon: _uploadingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(texts.text('merchant.menu.uploadPdf')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MerchantPremiumColors.ink,
                    side: const BorderSide(color: MerchantPremiumColors.line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        const Divider(color: MerchantPremiumColors.line, height: 1),
        // 👁 Vorschau: so sehen es Kunden.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.visibility_rounded,
              color: MerchantPremiumColors.muted, size: 22),
          title: Text(
            texts.text('merchant.menu.preview'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: MerchantPremiumColors.muted),
          onTap: widget.merchantId.isEmpty
              ? null
              : () {
                  // Router VOR dem pop greifen (Sheet-Context ist danach tot).
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push('/shop/${widget.merchantId}');
                },
        ),
      ],
    );
  }
}

/// Eine kompakte Options-Zeile: Icon + Titel (+ Badge) + ⓘ-Tooltip + Switch.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.tooltip,
    required this.enabled,
    required this.value,
    required this.onChanged,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String tooltip;
  final String? badge;
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.goldSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: MerchantPremiumColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MerchantPremiumColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: MerchantPremiumColors.gold.withValues(alpha: 0.32)),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: MerchantPremiumColors.gold,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Tooltip(
            message: tooltip,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 6),
            child: const Icon(Icons.info_outline_rounded,
                color: MerchantPremiumColors.muted, size: 17),
          ),
          const Spacer(),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texts.text('merchant.menu.error.load'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onRetry,
          child: Text(texts.text('common.refresh')),
        ),
      ],
    );
  }
}
