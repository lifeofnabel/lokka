import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/geoapifyService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../feedManager/widgets/squareImageCropSheet.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantShopSettingsPage extends StatelessWidget {
  const MerchantShopSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantShopProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantShopView(),
    );
  }
}

/// Steuert die schwebende Speichern-Leiste: das Formular meldet hier seinen
/// „dirty"-Status und seine Speichern-Aktion, die Leiste (außerhalb der
/// scrollbaren Liste) hört darauf und zeigt sich nur bei Änderungen.
class _SaveBarController extends ChangeNotifier {
  bool _dirty = false;
  Future<void> Function()? onSave;

  bool get dirty => _dirty;

  void setDirty(bool value) {
    if (_dirty == value) return;
    _dirty = value;
    notifyListeners();
  }
}

class _MerchantShopView extends StatefulWidget {
  const _MerchantShopView();

  @override
  State<_MerchantShopView> createState() => _MerchantShopViewState();
}

class _MerchantShopViewState extends State<_MerchantShopView> {
  final _saveBar = _SaveBarController();

  @override
  void dispose() {
    _saveBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantShopProvider>();
    final texts = context.watch<LanguageService>();
    return Stack(
      children: [
        MerchantToolScaffold(
          title: texts.text('merchant.shop.title'),
          subtitle: texts.text('merchant.shop.subtitle'),
          trailing: MerchantInfoTooltip(message: texts.text('merchant.shop.tooltip')),
          // Eigener, ruhiger Topper im Body -> der große Header des Scaffolds
          // wird ausgeblendet, damit der Titel nicht doppelt erscheint.
          showHeader: false,
          child: provider.isLoading
              ? const MerchantLoadingCards(count: 6)
              : provider.error != null
                  ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
                  : _ShopForm(saveBar: _saveBar),
        ),
        // Schwebende Speichern-Leiste: nur sichtbar, wenn etwas geändert wurde.
        if (!provider.isLoading && provider.error == null)
          _FloatingSaveBar(controller: _saveBar, isSaving: provider.isSaving),
      ],
    );
  }
}

/// Unten verankerte, schwebende Leiste mit dem Speichern-Button. Sie taucht
/// sanft auf, sobald der Nutzer etwas geändert hat, und verschwindet nach
/// erfolgreichem Speichern wieder.
class _FloatingSaveBar extends StatelessWidget {
  const _FloatingSaveBar({required this.controller, required this.isSaving});

  final _SaveBarController controller;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final visible = controller.dirty || isSaving;
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(0, 1.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: visible ? 1 : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.base.withValues(alpha: 0.96),
                    border: const Border(
                      top: BorderSide(color: MerchantPremiumColors.line),
                    ),
                    boxShadow: MerchantPremiumShadows.card,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: MerchantPrimaryButton(
                            label: texts.text('merchant.shop.save'),
                            isLoading: isSaving,
                            onPressed: () => controller.onSave?.call(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShopForm extends StatefulWidget {
  const _ShopForm({required this.saveBar});

  final _SaveBarController saveBar;

  @override
  State<_ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<_ShopForm> {
  // Land ist projektweit fix: Deutschland (DE). Kein Eingabefeld mehr.
  static const String _country = 'Deutschland';

  final shopName = TextEditingController();
  final description = TextEditingController();
  final publicNotice = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final street = TextEditingController();
  final houseNumber = TextEditingController();
  final postalCode = TextEditingController();
  final city = TextEditingController();
  final logoUrl = TextEditingController();
  final coverUrl = TextEditingController();
  final website = TextEditingController();
  final instagram = TextEditingController();
  final tiktok = TextEditingController();
  final facebook = TextEditingController();

  /// Bis zu 5 Shop-Fotos; das gewählte Cover ist immer Teil dieser Liste
  /// und wird zusätzlich als coverUrl gespeichert (eine Stelle für Bilder).
  static const int _maxGalleryImages = 5;
  final List<String> galleryImages = [];
  bool _galleryUploading = false;
  bool _logoUploading = false;

  final Map<String, List<_HourSlot>> openingHours = {};
  final Map<String, bool> closed = {};
  final List<String> selectedShopTypes = [];

  /// Herkunft (z. B. Italienisch, Türkisch): Mehrfachauswahl ohne Limit.
  final List<String> selectedOrigins = [];
  List<String> originOptions = [];

  bool phoneVerified = false;
  // Bewusste Sichtbarkeits-Wahl des Merchants (#44): nicht mehr aus
  // Vollständigkeit abgeleitet. Default: sichtbar.
  bool _publicVisible = true;
  bool _filled = false;
  bool _hydrating = false;

  // Geoapify: Koordinaten werden automatisch berechnet, sobald die Adresse
  // vollständig ist (kein Button-Klick mehr). Angezeigt wird nur eine kurze
  // Zeile unter „Land" (Adresse + Koordinaten).
  bool _geoLoading = false;
  bool _geoResolved = false;
  bool _geoNoKey = false;
  GeoResult? _geoResult;
  Timer? _geoDebounce;
  // Gespeicherte Koordinaten aus der Datenbank → sofort anzeigbar ohne API-Call
  // beim Öffnen. Werden verworfen, sobald der Merchant die Adresse ändert.
  double? _savedLat;
  double? _savedLng;
  String _savedFormatted = '';

  @override
  void initState() {
    super.initState();
    for (final day in _days) {
      openingHours[day.key] = [const _HourSlot(open: '09:00', close: '18:00')];
      closed[day.key] = false;
    }
    // Jede Texteingabe markiert das Formular als „geändert" (dirty) und löst
    // damit die schwebende Speichern-Leiste aus; einige Felder triggern
    // zusätzlich das Neuzeichnen von Vollständigkeits-/Hero-Vorschau.
    for (final controller in [
      shopName,
      phone,
      logoUrl,
      coverUrl,
    ]) {
      controller.addListener(_refreshCompletion);
    }
    // Adressfelder: aktualisieren die Live-Query und verwerfen ein
    // veraltetes aufgelöstes Ergebnis, sobald sich die Adresse ändert.
    for (final controller in [
      street,
      houseNumber,
      postalCode,
      city,
    ]) {
      controller.addListener(_onAddressChanged);
    }
    // Dirty-Tracking für ALLE Eingabefelder.
    for (final controller in _allControllers) {
      controller.addListener(_markDirty);
    }
    // Speichern-Aktion bei der schwebenden Leiste registrieren.
    widget.saveBar.onSave = _saveFromBar;
    _loadOrigins();
  }

  List<TextEditingController> get _allControllers => [
        shopName,
        description,
        publicNotice,
        email,
        phone,
        street,
        houseNumber,
        postalCode,
        city,
        logoUrl,
        coverUrl,
        website,
        instagram,
        tiktok,
        facebook,
      ];

  /// Markiert ungespeicherte Änderungen (während des Befüllens unterdrückt).
  void _markDirty() {
    if (_hydrating) return;
    widget.saveBar.setDirty(true);
  }

  /// Speichern-Trigger der schwebenden Leiste – nutzt denselben Provider-Save.
  Future<void> _saveFromBar() {
    return _save(context, context.read<MerchantShopProvider>());
  }

  /// Lädt die Herkunfts-Optionen (chooser/shopTypes → origins) direkt über
  /// den FirestoreService; bei Fehler bleibt die Liste einfach leer.
  Future<void> _loadOrigins() async {
    try {
      final origins = await context.read<FirestoreService>().loadChooserOrigins();
      if (!mounted) return;
      setState(() => originOptions = origins);
    } catch (_) {
      // Graceful: Sektion zeigt dann nur die Kategorien.
    }
  }

  void _refreshCompletion() {
    if (_hydrating) return;
    if (mounted) setState(() {});
  }

  void _onAddressChanged() {
    if (_hydrating) return;
    if (!mounted) return;
    setState(() {
      // Bisheriges Ergebnis (auch das gespeicherte) ist stale, sobald die
      // Adresse bearbeitet wird.
      _geoResolved = false;
      _geoResult = null;
      _savedLat = null;
      _savedLng = null;
    });
    // Automatisch neu berechnen, sobald der Nutzer kurz nicht mehr tippt und die
    // Adresse vollständig genug ist (kein „Vorschau"-Button mehr).
    _geoDebounce?.cancel();
    _geoDebounce = Timer(const Duration(milliseconds: 900), () {
      if (mounted && _addressResolvable()) _resolveGeo();
    });
  }

  /// Adresse hat genug Bestandteile für ein sinnvolles Geocoding.
  bool _addressResolvable() =>
      street.text.trim().isNotEmpty &&
      postalCode.text.trim().isNotEmpty &&
      city.text.trim().isNotEmpty;

  /// Query-String, der exakt so an Geoapify geht (vgl. forwardGeocode).
  String _geoQuery() {
    return [
      '${street.text.trim()} ${houseNumber.text.trim()}'.trim(),
      postalCode.text.trim(),
      city.text.trim(),
      'DE',
    ].where((part) => part.isNotEmpty).join(', ');
  }

  Future<void> _resolveGeo() async {
    if (_geoLoading) return;
    final service = GeoapifyService();
    // Unterscheidung „Key fehlt" vs. „Adresse nicht gefunden": .env wird beim
    // Build gebündelt – nach Key-Eintrag ist ein kompletter Neustart nötig.
    if (!service.isConfigured) {
      setState(() {
        _geoResolved = true;
        _geoNoKey = true;
        _geoResult = null;
      });
      return;
    }
    setState(() {
      _geoLoading = true;
      _geoNoKey = false;
    });
    final result = await service.forwardGeocode(
      street: street.text.trim(),
      houseNumber: houseNumber.text.trim(),
      postalCode: postalCode.text.trim(),
      city: city.text.trim(),
      country: _country,
    );
    if (!mounted) return;
    setState(() {
      _geoLoading = false;
      _geoResolved = true;
      _geoResult = result;
    });
  }

  /// Kurze Adresse + Koordinaten-Zeile unter „Land" (klein). Zeigt das frisch
  /// berechnete Ergebnis, sonst die gespeicherten Werte, sonst nichts. Nur die
  /// Daten, die den Merchant interessieren.
  Widget _geoLine(LanguageService texts) {
    const small = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    if (_geoLoading) {
      return Row(
        children: [
          const SizedBox(
              width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('Adresse wird geprüft …',
              style: small.copyWith(color: MerchantPremiumColors.muted)),
        ],
      );
    }
    final r = _geoResult;
    if (r != null) {
      return Text(
        '${r.formatted} + ${r.lat.toStringAsFixed(5)}, ${r.lng.toStringAsFixed(5)}',
        style: small.copyWith(color: MerchantPremiumColors.success),
      );
    }
    if (_savedLat != null && _savedLng != null) {
      final where = _savedFormatted.isNotEmpty ? _savedFormatted : _geoQuery();
      return Text(
        '$where + ${_savedLat!.toStringAsFixed(5)}, ${_savedLng!.toStringAsFixed(5)}',
        style: small.copyWith(color: MerchantPremiumColors.success),
      );
    }
    if (_geoResolved) {
      return Text(
        _geoNoKey
            ? 'Kein Geoapify-Key geladen – App neu builden.'
            : texts.text('merchant.shop.geoNotFound'),
        style: small.copyWith(color: MerchantPremiumColors.warning),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _geoDebounce?.cancel();
    widget.saveBar.onSave = null;
    for (final controller in _allControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantShopProvider>();
    final texts = context.watch<LanguageService>();
    _fill(provider);
    final missingFields = _missingFields(texts);

    // Vollständigkeit je Sektion → ✓/!-Pip im Kopf (Überblick ohne Aufklappen).
    final baseDone =
        shopName.text.trim().isNotEmpty && phone.text.trim().isNotEmpty;
    final addressDone = street.text.trim().isNotEmpty &&
        houseNumber.text.trim().isNotEmpty &&
        postalCode.text.trim().isNotEmpty &&
        city.text.trim().isNotEmpty;
    final categoryDone = selectedShopTypes.isNotEmpty;
    final hoursDone = _hasOpeningHours();
    final imagesDone =
        logoUrl.text.trim().isNotEmpty && coverUrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShopHero(
          shopName: shopName.text,
          city: city.text.trim(),
          shopTypes: selectedShopTypes,
          logoUrl: logoUrl.text,
          coverUrl: coverUrl.text,
          logoUploading: _logoUploading,
          // Logo wird NUR durch Tippen auf das Logo selbst geändert.
          onLogoTap: () => _changeLogo(provider),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!phoneVerified) _PhoneWarning(onVerify: () => _markPhoneVerified(context, provider)),
        _ProfileCompletionCard(missingFields: missingFields),
        _SectionCard(
          icon: Icons.storefront_rounded,
          initiallyExpanded: true,
          done: baseDone,
          title: texts.text('merchant.shop.section.base'),
          children: [
            // Ein einziges Namensfeld; beim Speichern werden shopName UND
            // businessName mit diesem Wert geschrieben (Kompatibilität).
            MerchantTextField(controller: shopName, label: texts.text('merchant.shop.nameUnified')),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: description, label: texts.text('common.description'), maxLines: 3),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: publicNotice, label: texts.text('merchant.shop.publicNotice'), maxLines: 2),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: email, label: texts.text('auth.email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: phone, label: texts.text('auth.phone'), keyboardType: TextInputType.phone),
          ],
        ),
        _SectionCard(
          icon: Icons.location_on_rounded,
          done: addressDone,
          title: texts.text('merchant.shop.section.address'),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 420;
                return stacked
                    ? Column(
                        children: [
                          MerchantTextField(controller: street, label: texts.text('auth.street')),
                          const SizedBox(height: AppSpacing.sm),
                          MerchantTextField(controller: houseNumber, label: texts.text('auth.houseNumber')),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 3, child: MerchantTextField(controller: street, label: texts.text('auth.street'))),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: MerchantTextField(controller: houseNumber, label: texts.text('auth.houseNumber'))),
                        ],
                      );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 420;
                return stacked
                    ? Column(
                        children: [
                          MerchantTextField(controller: postalCode, label: texts.text('auth.postalCode')),
                          const SizedBox(height: AppSpacing.sm),
                          MerchantTextField(controller: city, label: texts.text('auth.city')),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: MerchantTextField(controller: postalCode, label: texts.text('auth.postalCode'))),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(flex: 2, child: MerchantTextField(controller: city, label: texts.text('auth.city'))),
                        ],
                      );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            // Land ist fix Deutschland (DE) – kein Eingabefeld mehr.
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 16, color: MerchantPremiumColors.muted),
                const SizedBox(width: 8),
                Text(
                  texts.text('merchant.shop.countryFixed'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _geoLine(texts),
          ],
        ),
        _SectionCard(
          icon: Icons.category_rounded,
          done: categoryDone,
          title: 'Kategorie & Herkunft',
          children: [
            Text(texts.text('merchant.shop.maxCategories'), style: const TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            // Lange Listen werden eingeklappt: nur die ersten Chips sichtbar,
            // ausgewählte stehen immer vorn und bleiben sichtbar.
            _CollapsibleChips(
              options: _shopTypeChoices(provider),
              selected: selectedShopTypes,
              onToggle: _toggleShopType,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Herkunft', style: TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Woher kommt dein Angebot? Mehrfachauswahl möglich – z. B. Italienisch, Türkisch.',
              style: TextStyle(
                color: MerchantPremiumColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_originChoices.isEmpty)
              const Text(
                'Aktuell sind keine Herkunfts-Optionen verfügbar.',
                style: TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              _CollapsibleChips(
                options: _originChoices,
                selected: selectedOrigins,
                onToggle: _toggleOrigin,
              ),
            const SizedBox(height: AppSpacing.sm),
            const _MissingOptionHint(),
          ],
        ),
        _SectionCard(
          icon: Icons.schedule_rounded,
          done: hoursDone,
          title: texts.text('merchant.shop.section.openingHours'),
          children: [
            // Kompakte Zusammenfassung statt langer Inline-Editor.
            _OpeningHoursSummary(
              lines: _days
                  .map(
                    (day) => _HoursSummaryLine(
                      label: texts.text(day.labelKey),
                      value: (closed[day.key] ?? false)
                          ? texts.text('merchant.shop.closed')
                          : (openingHours[day.key] ?? const <_HourSlot>[])
                              .map((slot) => '${slot.open}-${slot.close}')
                              .join(', '),
                      isClosed: closed[day.key] ?? false,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => _openHoursEditorSheet(context),
              icon: const Icon(Icons.schedule_rounded),
              label: Text(texts.text('merchant.shop.editOpeningHours')),
            ),
          ],
        ),
        _SectionCard(
          icon: Icons.share_rounded,
          title: texts.text('merchant.shop.section.social'),
          children: [
            // Benutzernamen reichen: beim Speichern werden daraus volle URLs
            // (z. B. '@lokka' → https://instagram.com/lokka).
            const Text(
              'Benutzername genügt – wir machen daraus automatisch den Link.',
              style: TextStyle(
                color: MerchantPremiumColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: website,
              label: texts.text('merchant.shop.social.website'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: instagram,
              label: texts.text('merchant.shop.social.instagram'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: tiktok,
              label: texts.text('merchant.shop.social.tiktok'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: facebook,
              label: texts.text('merchant.shop.social.facebook'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        _SectionCard(
          icon: Icons.photo_library_rounded,
          done: imagesDone,
          title: texts.text('merchant.shop.images'),
          children: [
            Text(
              texts.text('merchant.shop.galleryHint'),
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _GalleryGrid(
              images: galleryImages,
              coverUrl: coverUrl.text.trim(),
              uploading: _galleryUploading,
              onAdd: () => _addGalleryImage(provider),
              onRemove: _removeGalleryImage,
              onSetCover: _setGalleryCover,
            ),
          ],
        ),
        _SectionCard(
          icon: Icons.visibility_rounded,
          title: texts.text('merchant.shop.visibility'),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _publicVisible,
              onChanged: (value) {
                setState(() => _publicVisible = value);
                _markDirty();
              },
              title: Text(
                texts.text('merchant.shop.visibilityToggle'),
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                texts.text('merchant.shop.visibilityHint'),
                style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const _FeaturesNavTile(),
        // Statischer Speichern-Button entfernt: Speichern erfolgt jetzt über
        // die schwebende Leiste am unteren Rand (nur bei Änderungen sichtbar).
        // Platz, damit die letzte Kachel nicht unter der Leiste verschwindet.
        const SizedBox(height: 84),
      ],
    );
  }

  void _fill(MerchantShopProvider provider) {
    if (_filled) return;
    _filled = true;
    _hydrating = true;
    final data = provider.merchant ?? {};
    // Vereinheitlichtes Namensfeld: bevorzugt shopName, sonst businessName.
    shopName.text = (data['shopName']?.toString().trim().isNotEmpty == true)
        ? data['shopName'].toString()
        : (data['businessName']?.toString() ?? '');
    description.text = data['description']?.toString() ?? '';
    publicNotice.text = data['publicNotice']?.toString() ?? '';
    email.text = data['email']?.toString() ?? '';
    phone.text = data['phone']?.toString() ?? '';
    street.text = data['street']?.toString() ?? '';
    houseNumber.text = data['houseNumber']?.toString() ?? '';
    postalCode.text = data['postalCode']?.toString() ?? '';
    city.text = data['city']?.toString() ?? '';
    // Gespeicherte Koordinaten sofort anzeigbar machen (kein API-Call beim
    // Öffnen); die kurze Zeile unter „Land" nutzt sie.
    _savedLat = (data['lat'] as num?)?.toDouble();
    _savedLng = (data['lng'] as num?)?.toDouble();
    final addressData = data['addressData'];
    _savedFormatted = (data['formattedAddress'] ??
            (addressData is Map ? addressData['formattedAddress'] : null) ??
            '')
        .toString();
    logoUrl.text = data['logoUrl']?.toString() ?? '';
    coverUrl.text = data['coverUrl']?.toString() ?? '';

    // Social-Links werden als volle URLs gespeichert, hier aber nur als
    // Benutzername/Domain angezeigt (der volle Link lebt in der Datenbank).
    final socials = data['socialLinks'];
    if (socials is Map) {
      website.text = _socialHandle('website', socials['website']?.toString() ?? '');
      instagram.text = _socialHandle('instagram', socials['instagram']?.toString() ?? '');
      tiktok.text = _socialHandle('tiktok', socials['tiktok']?.toString() ?? '');
      facebook.text = _socialHandle('facebook', socials['facebook']?.toString() ?? '');
    }

    // Galerie: bis zu 5 Fotos; ein bestehendes Cover, das nicht in der
    // Liste steckt (Altbestand), wird als erstes Bild behandelt.
    final rawGallery = data['galleryImages'];
    if (rawGallery is Iterable) {
      galleryImages.addAll(
        rawGallery
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(_maxGalleryImages),
      );
    }
    final existingCover = coverUrl.text.trim();
    if (existingCover.isNotEmpty && !galleryImages.contains(existingCover)) {
      galleryImages.insert(0, existingCover);
      if (galleryImages.length > _maxGalleryImages) {
        galleryImages.removeRange(_maxGalleryImages, galleryImages.length);
      }
    } else if (existingCover.isEmpty && galleryImages.isNotEmpty) {
      // Fotos ohne gewähltes Cover: erstes Foto übernimmt (wie beim Speichern).
      coverUrl.text = galleryImages.first;
    }

    phoneVerified = data['phoneVerified'] as bool? ?? false;
    // Opt-out respektieren (#44); ältere Profile ohne das Feld bleiben sichtbar.
    _publicVisible = !(data['visibilityOptOut'] as bool? ?? false);

    final rawTypes = data['shopTypes'];
    if (rawTypes is Iterable) {
      selectedShopTypes.addAll(rawTypes.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).take(2));
    } else {
      final type = data['shopType']?.toString() ?? '';
      if (type.isNotEmpty) selectedShopTypes.add(type);
    }

    final rawOrigins = data['origins'];
    if (rawOrigins is Iterable) {
      selectedOrigins.addAll(
        rawOrigins.map((item) => item.toString()).where((item) => item.trim().isNotEmpty),
      );
    }

    final hours = data['openingHours'];
    if (hours is Map) {
      for (final day in _days) {
        final dayData = hours[day.key];
        if (dayData is Map) {
          closed[day.key] = dayData['closed'] as bool? ?? false;
          final slots = dayData['slots'];
          if (slots is Iterable) {
            openingHours[day.key] = slots
                .whereType<Map>()
                .map((slot) => _HourSlot(open: slot['open']?.toString() ?? '09:00', close: slot['close']?.toString() ?? '18:00'))
                .toList();
          } else {
            openingHours[day.key] = [
              _HourSlot(open: dayData['open']?.toString() ?? '09:00', close: dayData['close']?.toString() ?? '18:00'),
            ];
          }
        }
      }
    }
    _hydrating = false;
  }

  void _toggleShopType(String type) {
    // Max. 2 Kategorien: eine 3. Auswahl ändert nichts, nur Hinweis zeigen.
    if (!selectedShopTypes.contains(type) && selectedShopTypes.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max. 2 Kategorien – bitte zuerst eine abwählen.')),
      );
      return;
    }
    setState(() {
      if (selectedShopTypes.contains(type)) {
        selectedShopTypes.remove(type);
      } else {
        selectedShopTypes.add(type);
      }
    });
    _markDirty();
  }

  void _toggleOrigin(String origin) {
    setState(() {
      if (selectedOrigins.contains(origin)) {
        selectedOrigins.remove(origin);
      } else {
        selectedOrigins.add(origin);
      }
    });
    _markDirty();
  }

  /// Anzeige-Liste der Kategorie-Chips: geladene Optionen plus bereits
  /// gewählte Werte (z. B. selbst getippte), damit nichts „verschwindet".
  List<String> _shopTypeChoices(MerchantShopProvider provider) => {
        ...provider.shopTypes,
        ...selectedShopTypes,
      }.toList();

  /// Anzeige-Liste der Herkunfts-Chips: geladene Optionen plus bereits
  /// gespeicherte Werte (Altbestand), damit nichts „verschwindet".
  List<String> get _originChoices => {
        ...originOptions,
        ...selectedOrigins,
      }.toList();

  /// Lädt ein Galerie-Foto hoch – OHNE manuelles Zuschneiden (Shop-Bilder sollen
  /// schnell rein; das Beschneiden bleibt Beiträgen und dem Logo vorbehalten).
  /// Der UploadService optimiert die Datei weiterhin automatisch. Das erste Foto
  /// wird zum Cover, falls noch keins gewählt ist.
  Future<void> _addGalleryImage(MerchantShopProvider provider) async {
    if (_galleryUploading || galleryImages.length >= _maxGalleryImages) return;
    setState(() => _galleryUploading = true);
    final url = await _pickUploadNoCrop(provider, UploadImageType.item);
    if (!mounted) return;
    setState(() {
      _galleryUploading = false;
      if (url == null || url.isEmpty) return;
      if (!galleryImages.contains(url) && galleryImages.length < _maxGalleryImages) {
        galleryImages.add(url);
      }
      if (coverUrl.text.trim().isEmpty) coverUrl.text = url;
    });
    if (url != null && url.isNotEmpty) _markDirty();
  }

  void _removeGalleryImage(String url) {
    setState(() {
      galleryImages.remove(url);
      // War das Bild das Cover, rückt das erste verbleibende Foto nach.
      if (coverUrl.text.trim() == url) {
        coverUrl.text = galleryImages.isNotEmpty ? galleryImages.first : '';
      }
    });
    _markDirty();
  }

  void _setGalleryCover(String url) {
    setState(() => coverUrl.text = url);
    _markDirty();
  }

  /// Logo ändern – wird NUR durch Tippen auf das Logo im Hero ausgelöst.
  /// Das Bild wird auf 1:1 zugeschnitten und mit dem bestehenden
  /// Upload-Mechanismus hochgeladen.
  Future<void> _changeLogo(MerchantShopProvider provider) async {
    if (_logoUploading) return;
    setState(() => _logoUploading = true);
    final url = await _pickCropUploadSquare(provider, UploadImageType.logo);
    if (!mounted) return;
    setState(() {
      _logoUploading = false;
      if (url != null && url.isNotEmpty) logoUrl.text = url;
    });
    // logoUrl hat einen Listener -> _markDirty wird bereits ausgelöst.
  }

  /// Wählt ein Bild, schneidet es im Square-Crop-Sheet auf 1:1 und lädt es
  /// über den bestehenden UploadService hoch. Gibt die finale URL zurück
  /// (oder null bei Abbruch/Fehler). Bleibt mit dem alten Mechanismus
  /// kompatibel (gleicher Storage-Upload, nur mit Vorab-Zuschnitt).
  Future<String?> _pickCropUploadSquare(
    MerchantShopProvider provider,
    UploadImageType type,
  ) async {
    final uploadService = provider.uploadService;
    final picked = await uploadService.pickImageWithFilePicker();
    if (picked == null || !mounted) return null;
    final Uint8List? cropped = await showSquareImageCropSheet(
      context: context,
      imageBytes: picked.bytes,
    );
    if (cropped == null || !mounted) return null;
    return _uploadBytes(provider, cropped, picked.fileName, type);
  }

  /// Wählt ein Bild und lädt es DIREKT hoch – ohne Zuschneide-Sheet. Für
  /// Shop-Galerie-Bilder gedacht.
  Future<String?> _pickUploadNoCrop(
    MerchantShopProvider provider,
    UploadImageType type,
  ) async {
    final picked = await provider.uploadService.pickImageWithFilePicker();
    if (picked == null || !mounted) return null;
    return _uploadBytes(provider, picked.bytes, picked.fileName, type);
  }

  Future<String?> _uploadBytes(
    MerchantShopProvider provider,
    Uint8List bytes,
    String fileName,
    UploadImageType type,
  ) async {
    try {
      final media = await provider.uploadService.uploadOptimizedImageBytes(
        bytes: bytes,
        fileName: fileName,
        type: type,
      );
      final url = media.secureUrl.isNotEmpty ? media.secureUrl : media.url;
      return url.isNotEmpty ? url : null;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild konnte nicht hochgeladen werden.')),
        );
      }
      return null;
    }
  }

  Future<void> _markPhoneVerified(BuildContext context, MerchantShopProvider provider) async {
    final texts = context.read<LanguageService>();
    await provider.markPhoneVerified();
    setState(() => phoneVerified = true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texts.text('merchant.shop.phoneMarked'))));
    }
  }

  /// Kompakter Sammel-Sheet: listet alle Tage; ein Tippen öffnet den
  /// bestehenden Pro-Tag-Editor. Datenform bleibt unverändert.
  Future<void> _openHoursEditorSheet(BuildContext context) async {
    final texts = context.read<LanguageService>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(14),
          child: MerchantPremiumCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            radius: 32,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MerchantPremiumColors.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      texts.text('merchant.shop.section.openingHours'),
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._days.map(
                      (day) => _OpeningHoursTile(
                        label: texts.text(day.labelKey),
                        closed: closed[day.key] ?? false,
                        slots: openingHours[day.key] ?? const [],
                        // Pro-Tag-Editor öffnen, danach Sheet-Zeilen neu zeichnen.
                        onTap: () async {
                          await _openHoursSheet(context, day);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MerchantPrimaryButton(
                      label: texts.text('common.save'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openHoursSheet(BuildContext context, _Day day) async {
    final texts = context.read<LanguageService>();
    var isClosed = closed[day.key] ?? false;
    final slots = List<_HourSlot>.from(openingHours[day.key] ?? [const _HourSlot(open: '09:00', close: '18:00')]);
    final openControllers = slots.map((slot) => TextEditingController(text: slot.open)).toList();
    final closeControllers = slots.map((slot) => TextEditingController(text: slot.close)).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(context).viewInsets.bottom + 14),
          child: MerchantPremiumCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            radius: 32,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MerchantPremiumColors.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    texts.text(day.labelKey),
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    value: isClosed,
                    onChanged: (value) => setSheetState(() => isClosed = value),
                    title: Text(texts.text('merchant.shop.closed')),
                  ),
                  if (!isClosed)
                    ...List.generate(openControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TimeButton(
                                label: texts.text('merchant.shop.from'),
                                value: openControllers[index].text,
                                onTap: () async {
                                  final picked = await _pickTime(
                                    context,
                                    openControllers[index].text,
                                  );
                                  if (picked != null) {
                                    setSheetState(() {
                                      openControllers[index].text = picked;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _TimeButton(
                                label: texts.text('merchant.shop.to'),
                                value: closeControllers[index].text,
                                onTap: () async {
                                  final picked = await _pickTime(
                                    context,
                                    closeControllers[index].text,
                                  );
                                  if (picked != null) {
                                    setSheetState(() {
                                      closeControllers[index].text = picked;
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: openControllers.length <= 1
                                  ? null
                                  : () => setSheetState(() {
                                        openControllers.removeAt(index);
                                        closeControllers.removeAt(index);
                                      }),
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (!isClosed)
                    OutlinedButton.icon(
                      onPressed: () => setSheetState(() {
                        openControllers.add(TextEditingController(text: '17:00'));
                        closeControllers.add(TextEditingController(text: '22:00'));
                      }),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(texts.text('merchant.shop.addBreak')),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          _applyHoursToAll(isClosed, openControllers, closeControllers);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(texts.text('merchant.shop.applyAll')),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          _applyHoursToWorkdays(isClosed, openControllers, closeControllers);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(texts.text('merchant.shop.applyWorkdays')),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MerchantPrimaryButton(
                    label: texts.text('common.save'),
                    onPressed: () {
                      _setHours(day.key, isClosed, openControllers, closeControllers);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final controller in [...openControllers, ...closeControllers]) {
      controller.dispose();
    }
  }

  void _applyHoursToAll(bool isClosed, List<TextEditingController> openControllers, List<TextEditingController> closeControllers) {
    setState(() {
      for (final day in _days) {
        _setHours(day.key, isClosed, openControllers, closeControllers, notify: false);
      }
    });
  }

  void _applyHoursToWorkdays(bool isClosed, List<TextEditingController> openControllers, List<TextEditingController> closeControllers) {
    setState(() {
      for (final day in _days.take(5)) {
        _setHours(day.key, isClosed, openControllers, closeControllers, notify: false);
      }
    });
  }

  void _setHours(
    String dayKey,
    bool isClosed,
    List<TextEditingController> openControllers,
    List<TextEditingController> closeControllers, {
    bool notify = true,
  }) {
    void update() {
      closed[dayKey] = isClosed;
      openingHours[dayKey] = [
        for (var i = 0; i < openControllers.length; i++)
          _HourSlot(open: openControllers[i].text.trim(), close: closeControllers[i].text.trim()),
      ];
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
    _markDirty();
  }

  Future<void> _save(BuildContext context, MerchantShopProvider provider) async {
    final texts = context.read<LanguageService>();
    final missing = _missingFields(texts);
    final primary = selectedShopTypes.isEmpty ? '' : selectedShopTypes.first;
    final isComplete = missing.isEmpty;
    // Ein Namensfeld -> beide Felder mit demselben Wert schreiben, damit
    // bestehender Code (liest shopName ODER businessName) kompatibel bleibt.
    final unifiedName = shopName.text.trim();
    // Social-Links: Benutzernamen werden zu vollen URLs erweitert
    // (z. B. '@lokka' → https://instagram.com/lokka); leere Werte fliegen raus.
    final socialLinks = <String, String>{
      'website': _expandSocialLink('website', website.text),
      'instagram': _expandSocialLink('instagram', instagram.text),
      'tiktok': _expandSocialLink('tiktok', tiktok.text),
      'facebook': _expandSocialLink('facebook', facebook.text),
    }..removeWhere((key, value) => value.isEmpty);
    // Galerie (max 5) + Cover: das gewählte Cover wird zusätzlich als
    // coverUrl geschrieben; fehlt eins, rückt das erste Foto nach.
    final gallery = galleryImages
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .take(_maxGalleryImages)
        .toList();
    final chosenCover = coverUrl.text.trim().isNotEmpty
        ? coverUrl.text.trim()
        : (gallery.isNotEmpty ? gallery.first : '');
    await provider.save({
      'shopName': unifiedName,
      'businessName': unifiedName,
      'description': description.text.trim(),
      'publicNotice': publicNotice.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
      'phoneVerified': phoneVerified,
      'street': street.text.trim(),
      'houseNumber': houseNumber.text.trim(),
      'postalCode': postalCode.text.trim(),
      'city': city.text.trim(),
      'country': _country,
      'shopTypes': selectedShopTypes,
      'shopTypePrimary': primary,
      'shopType': primary,
      'origins': List<String>.from(selectedOrigins),
      // Falls die Adresse in der Vorschau schon aufgelöst wurde, die bestätigten
      // Koordinaten mitschicken – saveShopData nutzt sie als Fallback, falls die
      // erneute Geocodierung beim Speichern scheitert.
      if (_geoResult != null) 'lat': _geoResult!.lat,
      if (_geoResult != null) 'lng': _geoResult!.lng,
      'logoUrl': logoUrl.text.trim(),
      'coverUrl': chosenCover,
      'galleryImages': gallery,
      'socialLinks': socialLinks,
      'openingHours': {
        for (final day in _days)
          day.key: {
            'closed': closed[day.key] ?? false,
            'slots': [
              for (final slot in openingHours[day.key] ?? const <_HourSlot>[])
                {'open': slot.open, 'close': slot.close},
            ],
            'open': (openingHours[day.key]?.isNotEmpty ?? false) ? openingHours[day.key]!.first.open : '',
            'close': (openingHours[day.key]?.isNotEmpty ?? false) ? openingHours[day.key]!.first.close : '',
          },
      },
      // Sichtbarkeit als bewusste Wahl (#44): nur das Opt-out durchreichen –
      // isPublic/isActive berechnet der Service (eine Quelle der Wahrheit).
      'visibilityOptOut': !_publicVisible,
    });
    // Nach erfolgreichem Speichern verschwindet die schwebende Leiste wieder.
    if (provider.error == null) {
      widget.saveBar.setDirty(false);
    }
    if (context.mounted) {
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(texts.text('common.error'))),
        );
      } else if (isComplete) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texts.text('merchant.shop.saved'))));
      } else {
        _showCompletionSheet(context, missing);
      }
    }
  }

  List<String> _missingFields(LanguageService texts) {
    final missing = <String>[];
    if (shopName.text.trim().isEmpty) missing.add(texts.text('auth.shopName'));
    if (phone.text.trim().isEmpty) missing.add(texts.text('auth.phone'));
    if (!phoneVerified) missing.add(texts.text('merchant.shop.verifyPhone'));
    if (street.text.trim().isEmpty ||
        houseNumber.text.trim().isEmpty ||
        postalCode.text.trim().isEmpty ||
        city.text.trim().isEmpty) {
      missing.add(texts.text('merchant.shop.section.address'));
    }
    if (selectedShopTypes.isEmpty) missing.add(texts.text('auth.shopType'));
    if (logoUrl.text.trim().isEmpty) missing.add(texts.text('merchant.shop.logo'));
    if (coverUrl.text.trim().isEmpty) missing.add(texts.text('merchant.shop.cover'));
    if (!_hasOpeningHours()) missing.add(texts.text('merchant.shop.section.openingHours'));
    return missing;
  }

  bool _hasOpeningHours() {
    for (final day in _days) {
      if (closed[day.key] == true) continue;
      final slots = openingHours[day.key] ?? const <_HourSlot>[];
      if (slots.isEmpty) return false;
      for (final slot in slots) {
        if (slot.open.trim().isEmpty || slot.close.trim().isEmpty) return false;
      }
    }
    return true;
  }
}

class _ShopHero extends StatelessWidget {
  const _ShopHero({
    required this.shopName,
    required this.city,
    required this.shopTypes,
    required this.logoUrl,
    required this.coverUrl,
    required this.logoUploading,
    required this.onLogoTap,
  });

  final String shopName;
  final String city;
  final List<String> shopTypes;
  final String logoUrl;
  final String coverUrl;
  final bool logoUploading;
  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: MerchantPremiumColors.baseElevated,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: MerchantPremiumShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (coverUrl.isNotEmpty)
            CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover)
          else
            const DecoratedBox(decoration: BoxDecoration(color: MerchantPremiumColors.baseElevated)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.84),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Row(
                  children: [
                    // Logo wird NUR durch Tippen hier geändert (großes Tap-Ziel,
                    // klarer Hinweis-Badge). Kein separater Bilder-Sheet mehr.
                    InkWell(
                      onTap: logoUploading ? null : onLogoTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              // Passende Farbe aus dem Shopnamen: füllt den Kreis
                              // auch dann sauber, wenn kein Logo da ist oder das
                              // Logo transparente Stellen hat (PNG) → nie „leer".
                              color: _avatarColor(shopName),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: logoUploading
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                    ),
                                  )
                                : logoUrl.isEmpty
                                    ? Center(
                                        child: Text(
                                          _initials(shopName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      )
                                    : CachedNetworkImage(imageUrl: logoUrl, fit: BoxFit.cover),
                          ),
                          // Kleiner Stift-Badge signalisiert „antippbar".
                          if (!logoUploading)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: MerchantPremiumColors.baseElevated, width: 2),
                                ),
                                child: const Icon(Icons.edit_rounded, size: 13, color: AppColors.black),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName.trim().isEmpty ? texts.text('merchant.shop.defaultShop') : shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.white, fontSize: 25, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [city, shopTypes.join(', ')].where((item) => item.trim().isNotEmpty).join(' | '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MerchantPremiumColors.mutedLight,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneWarning extends StatelessWidget {
  const _PhoneWarning({required this.onVerify});

  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: MerchantPremiumColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texts.text('merchant.shop.phoneNotVerified'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            texts.text('merchant.shop.phoneWarning'),
            style: const TextStyle(
              color: MerchantPremiumColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onVerify,
            icon: const Icon(Icons.verified_rounded),
            label: Text(texts.text('merchant.shop.verifyPhone')),
          ),
        ],
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.missingFields});

  final List<String> missingFields;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final complete = missingFields.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: complete ? MerchantPremiumColors.mintSoft : MerchantPremiumColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: complete ? MerchantPremiumColors.mint : MerchantPremiumColors.gold,
        ),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: AppColors.black,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              complete
                  ? texts.text('merchant.shop.profilePublic')
                  : texts.text('merchant.shop.profilePrivate'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (!complete)
            Tooltip(
              message: missingFields.join(', '),
              child: const Icon(Icons.info_outline_rounded),
            ),
        ],
      ),
    );
  }
}

/// Einklappbare Sektion mit Icon + Chevron. Alle Sektionen eingeklappt geben
/// oben den Überblick über die Bereiche; gezielt einen aufklappen statt einer
/// endlosen Formular-Wand. Die Eingabe-Controller gehören dem Form-State, daher
/// gehen beim Einklappen KEINE Werte verloren.
class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.icon = Icons.tune_rounded,
    this.initiallyExpanded = false,
    this.done,
  });

  final String title;
  final List<Widget> children;
  final IconData icon;
  final bool initiallyExpanded;

  /// Vollständigkeits-Status für den Kopf: `true` = ✓ ausgefüllt, `false` =
  /// fehlt noch, `null` = optionaler Bereich (kein Badge). So sieht man ohne
  /// Aufklappen, wo noch etwas fehlt.
  final bool? done;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MerchantPremiumColors.goldSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(widget.icon,
                        size: 20, color: MerchantPremiumColors.gold),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (widget.done != null) ...[
                    _SectionStatus(done: widget.done!),
                    const SizedBox(width: 10),
                  ],
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: MerchantPremiumColors.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}

/// Kleiner Status-Pip im Sektions-Kopf: grünes ✓ (ausgefüllt) oder gelbes !
/// (fehlt noch). Gibt den Überblick, ohne die Sektion aufklappen zu müssen.
class _SectionStatus extends StatelessWidget {
  const _SectionStatus({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? MerchantPremiumColors.success : MerchantPremiumColors.warning;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Icon(
        done ? Icons.check_rounded : Icons.priority_high_rounded,
        size: 14,
        color: color,
      ),
    );
  }
}

/// Chip-Gruppe, die bei langen Listen einklappt: zeigt zunächst nur die
/// ersten Chips und blendet den Rest hinter „Mehr anzeigen (+N)" aus.
/// Ausgewählte Chips stehen immer vorn und bleiben damit sichtbar.
class _CollapsibleChips extends StatefulWidget {
  const _CollapsibleChips({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  /// Anzahl Chips im eingeklappten Zustand.
  static const int collapsedCount = 8;

  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  State<_CollapsibleChips> createState() => _CollapsibleChipsState();
}

class _CollapsibleChipsState extends State<_CollapsibleChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const collapsedCount = _CollapsibleChips.collapsedCount;
    // Ausgewählte zuerst (stabile Reihenfolge), damit gewählte Chips auch im
    // eingeklappten Zustand sichtbar bleiben.
    final selectedFirst = [
      ...widget.options.where(widget.selected.contains),
      ...widget.options.where((option) => !widget.selected.contains(option)),
    ];
    final total = selectedFirst.length;
    final showAll = _expanded || total <= collapsedCount;
    final visible = showAll ? selectedFirst : selectedFirst.take(collapsedCount).toList();
    final hiddenCount = total - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in visible)
              FilterChip(
                label: Text(option),
                selected: widget.selected.contains(option),
                onSelected: (_) => widget.onToggle(option),
              ),
          ],
        ),
        if (total > collapsedCount) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(_expanded ? 'Weniger' : 'Mehr anzeigen (+$hiddenCount)'),
              style: TextButton.styleFrom(foregroundColor: MerchantPremiumColors.gold),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hinweis unter den Auswahl-Chips: Kategorien & Herkunft sind feste Optionen
/// (nur Auswahl, kein freies Anlegen mehr). Fehlt ein Wunsch, führt
/// „Kontaktiere uns" direkt in die Support-Seite.
class _MissingOptionHint extends StatelessWidget {
  const _MissingOptionHint();

  @override
  Widget build(BuildContext context) {
    final texts = context.read<LanguageService>();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/merchant/tools/support'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: MerchantPremiumColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                children: [
                  TextSpan(text: '${texts.text('merchant.shop.optionMissing')} '),
                  TextSpan(
                    text: texts.text('merchant.shop.optionMissingContact'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.gold,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5 Foto-Slots: gefüllte Slots zeigen Thumbnail + Löschen (X) + Cover-Wahl,
/// leere Slots starten den Upload (gleicher Weg wie Logo/Cover).
class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({
    required this.images,
    required this.coverUrl,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
    required this.onSetCover,
  });

  static const int _slotCount = 5;

  final List<String> images;
  final String coverUrl;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onSetCover;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.sm;
        final perRow = constraints.maxWidth < 420 ? 3 : 5;
        final size = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        final emptySlots = _slotCount - images.length;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final url in images) _filledSlot(texts, url, size),
            for (var i = 0; i < emptySlots; i++)
              _emptySlot(size, showSpinner: uploading && i == 0),
          ],
        );
      },
    );
  }

  Widget _filledSlot(LanguageService texts, String url, double size) {
    final isCover = coverUrl.isNotEmpty && url == coverUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: isCover ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
          width: isCover ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          // Löschen (X) oben rechts.
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => onRemove(url),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          // Unten: Cover-Badge bzw. "Als Cover"-Aktion.
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            child: isCover
                ? _bottomChip(
                    label: texts.text('merchant.shop.galleryCover'),
                    background: MerchantPremiumColors.gold,
                    foreground: MerchantPremiumColors.base,
                    icon: Icons.star_rounded,
                  )
                : InkWell(
                    onTap: () => onSetCover(url),
                    borderRadius: BorderRadius.circular(999),
                    child: _bottomChip(
                      label: texts.text('merchant.shop.gallerySetCover'),
                      background: Colors.black.withValues(alpha: 0.62),
                      foreground: AppColors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bottomChip({
    required String label,
    required Color background,
    required Color foreground,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySlot(double size, {required bool showSpinner}) {
    return InkWell(
      onTap: uploading ? null : onAdd,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Center(
          child: showSpinner
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: MerchantPremiumColors.muted,
                ),
        ),
      ),
    );
  }
}

/// Kompakte Wochenübersicht der Öffnungszeiten (read-only Summary-Zeilen).
class _OpeningHoursSummary extends StatelessWidget {
  const _OpeningHoursSummary({required this.lines});

  final List<_HoursSummaryLine> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    line.label,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.value.isEmpty ? '—' : line.value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: line.isClosed ? MerchantPremiumColors.muted : MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HoursSummaryLine {
  const _HoursSummaryLine({
    required this.label,
    required this.value,
    required this.isClosed,
  });

  final String label;
  final String value;
  final bool isClosed;
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InputDecorator(
        decoration: merchantPremiumInputDecoration(label: label),
        child: Text(
          value,
          style: const TextStyle(
            color: MerchantPremiumColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OpeningHoursTile extends StatelessWidget {
  const _OpeningHoursTile({
    required this.label,
    required this.closed,
    required this.slots,
    required this.onTap,
  });

  final String label;
  final bool closed;
  final List<_HourSlot> slots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(closed ? texts.text('merchant.shop.closed') : slots.map((slot) => '${slot.open}-${slot.close}').join(', ')),
      trailing: IconButton(onPressed: onTap, icon: const Icon(Icons.edit_calendar_rounded)),
    );
  }
}

Future<String?> _pickTime(BuildContext context, String value) async {
  final parts = value.split(':');
  final initial = TimeOfDay(
    hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9,
    minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
  );
  final picked = await showTimePicker(
    context: context,
    initialTime: initial,
  );
  if (picked == null) return null;
  final hour = picked.hour.toString().padLeft(2, '0');
  final minute = picked.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

void _showCompletionSheet(BuildContext context, List<String> missingFields) {
  final texts = context.read<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(14),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        radius: 32,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                texts.text('merchant.shop.privateTitle'),
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...missingFields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.radio_button_unchecked_rounded,
                        color: MerchantPremiumColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          field,
                          style: const TextStyle(
                            color: MerchantPremiumColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPremiumColors.ink,
                  foregroundColor: MerchantPremiumColors.base,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(texts.text('common.ok')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Gut sichtbare Navigations-Kachel: „Meine Systeme" werden ab jetzt über
/// die Shopdaten erreicht (Funktionen verwalten → /merchant/features).
class _FeaturesNavTile extends StatelessWidget {
  const _FeaturesNavTile();

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push('/merchant/features'),
      child: const Row(
        children: [
          MerchantPremiumIconBox(icon: Icons.widgets_rounded),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Funktionen verwalten',
                  style: TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Meine Systeme: Module aktivieren & konfigurieren.',
                  style: TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: MerchantPremiumColors.muted,
            size: 16,
          ),
        ],
      ),
    );
  }
}

/// Zieht aus einer Social-Eingabe (Benutzername ODER voller Link) nur das
/// Wesentliche: den Benutzernamen (Instagram/TikTok/Facebook) bzw. die Domain
/// (Website). So zeigt das Feld immer nur den Username; gespeichert wird eine
/// saubere kanonische Form.
String _socialHandle(String type, String raw) {
  var v = raw.trim();
  if (v.isEmpty) return '';
  v = v.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  v = v.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
  if (type == 'website') {
    return v.split('/').first.trim(); // nur die Domain, z. B. babelimbiss.de
  }
  if (v.contains('/')) {
    final segs = v.split('/').where((s) => s.trim().isNotEmpty).toList();
    if (segs.isNotEmpty) v = segs.last; // letztes Pfadsegment = Handle
  }
  return v.replaceFirst('@', '').trim();
}

/// Baut aus der Social-Eingabe die volle URL fürs Speichern – funktioniert
/// sowohl mit einem bloßen Benutzernamen als auch mit einem eingefügten Link
/// (dann wird der Username extrahiert und kanonisch neu aufgebaut).
String _expandSocialLink(String type, String raw) {
  final handle = _socialHandle(type, raw);
  if (handle.isEmpty) return '';
  switch (type) {
    case 'website':
      return 'https://$handle';
    case 'instagram':
      return 'https://instagram.com/$handle';
    case 'tiktok':
      return 'https://www.tiktok.com/@$handle';
    case 'facebook':
      return 'https://facebook.com/$handle';
  }
  return 'https://$handle';
}

/// Deterministische, angenehme Avatar-Farbe aus dem Shopnamen (wie Kontakt-
/// Avatare) – füllt den Logo-Kreis sauber, wenn kein Bild da ist.
Color _avatarColor(String name) {
  const palette = [
    Color(0xFF1E7A5F),
    Color(0xFF2E7DD1),
    Color(0xFF8E5BD9),
    Color(0xFFD64545),
    Color(0xFFE8762A),
    Color(0xFFD94F8E),
    Color(0xFF1FA9A0),
    Color(0xFF4D58C9),
    Color(0xFF3FA45C),
  ];
  final key = name.trim().isEmpty ? 'L' : name.trim();
  var hash = 0;
  for (final code in key.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

class _Day {
  const _Day(this.key, this.labelKey);

  final String key;
  final String labelKey;
}

class _HourSlot {
  const _HourSlot({required this.open, required this.close});

  final String open;
  final String close;
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'L';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length < 2 ? parts.first.length : 2).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

const _days = [
  _Day('monday', 'day.monday'),
  _Day('tuesday', 'day.tuesday'),
  _Day('wednesday', 'day.wednesday'),
  _Day('thursday', 'day.thursday'),
  _Day('friday', 'day.friday'),
  _Day('saturday', 'day.saturday'),
  _Day('sunday', 'day.sunday'),
];
