import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/firestoreService.dart';
import '../../../core/services/geoapifyService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/services/legalService.dart';
import '../../../core/theme/appColors.dart';
import '../providers/authProvider.dart';
import '../services/authNavigation.dart';
import '../widgets/authFlowWidgets.dart';
import '../widgets/legalSheet.dart';

class MerchantRegisterPage extends StatefulWidget {
  const MerchantRegisterPage({super.key});

  @override
  State<MerchantRegisterPage> createState() => _MerchantRegisterPageState();
}

class _MerchantRegisterPageState extends State<MerchantRegisterPage> {
  final _shopName = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _houseNumber = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  String? _shopType;
  GeoResult? _address;
  String? _localError;
  late Future<_ChooserData> _chooserFuture;

  bool get _isGoogleCompletion => context.read<AuthProvider>().currentUser != null;

  /// Nur deutsche Rufnummern: das Feld hält NUR den nationalen Teil (nach +49).
  String get _fullPhone =>
      '+49${_phone.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '')}';

  @override
  void initState() {
    super.initState();
    _chooserFuture = _loadChooser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;
      final parts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
      _email.text = user.email ?? '';
      _firstName.text = parts.isNotEmpty ? parts.first : '';
      _lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    });
  }

  @override
  void dispose() {
    _shopName.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _street.dispose();
    _houseNumber.dispose();
    _postalCode.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<_ChooserData> _loadChooser() async {
    final provider = context.read<AuthProvider>();
    final shopTypes = await provider.loadShopTypes();
    return _ChooserData(shopTypes: [...shopTypes, 'Andere']);
  }

  void _onAddressPicked(GeoResult g) {
    setState(() {
      _address = g;
      _street.text = g.street;
      _houseNumber.text = g.houseNumber;
      _postalCode.text = g.postalCode;
      _city.text = g.city;
    });
  }

  Future<void> _register() async {
    final texts = context.read<LanguageService>();
    final shopType = _shopType ?? '';
    final values = [
      _shopName.text,
      _firstName.text,
      _lastName.text,
      _email.text,
      if (!_isGoogleCompletion) _password.text,
      _phone.text,
      _street.text,
      _houseNumber.text,
      _postalCode.text,
      _city.text,
      shopType,
    ];
    final error = validateRequiredAuth(
      texts: texts,
      values: values,
      email: _email.text,
      password: _isGoogleCompletion ? null : _password.text,
      checksRequired: true,
      checksAccepted: _terms && _privacy && _marketing,
    );
    if (error != null) {
      setState(() => _localError = error);
      return;
    }

    final provider = context.read<AuthProvider>();
    final destination = _isGoogleCompletion
        ? await provider.createGoogleMerchantProfile(
            shopName: _shopName.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _fullPhone,
            street: _street.text,
            houseNumber: _houseNumber.text,
            postalCode: _postalCode.text,
            city: _city.text,
            shopType: shopType,
          )
        : await provider.registerMerchant(
            shopName: _shopName.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            password: _password.text,
            phone: _fullPhone,
            street: _street.text,
            houseNumber: _houseNumber.text,
            postalCode: _postalCode.text,
            city: _city.text,
            shopType: shopType,
          );

    if (mounted && destination != null) {
      context.go(pathForAuthDestination(destination));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    return AuthPageShell(
      titleKey: 'auth.merchantRegister.title',
      subtitleKey: 'auth.merchantRegister.subtitle',
      dark: true,
      icon: Icons.storefront_rounded,
      children: [
        AuthErrorBox(message: _localError ?? provider.error),
        const AuthSectionLabel(labelKey: 'auth.section.shopOwner', topGap: 0),
        AuthTextField(controller: _shopName, labelKey: 'auth.shopName'),
        AuthFieldRow(
          first: AuthTextField(
              controller: _firstName, labelKey: 'auth.ownerFirstName'),
          second: AuthTextField(
              controller: _lastName, labelKey: 'auth.ownerLastName'),
        ),
        AuthTextField(
          controller: _phone,
          labelKey: 'auth.phone',
          prefixText: '+49 ',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const AuthSectionLabel(labelKey: 'auth.section.access'),
        AuthTextField(
          controller: _email,
          labelKey: 'auth.email',
          keyboardType: TextInputType.emailAddress,
        ),
        if (!_isGoogleCompletion)
          AuthTextField(
            controller: _password,
            labelKey: 'auth.password',
            obscureText: true,
          ),
        const AuthSectionLabel(labelKey: 'auth.section.address'),
        _AddressPicker(onPicked: _onAddressPicked, initial: _address),
        const AuthSectionLabel(labelKey: 'auth.section.category'),
        FutureBuilder<_ChooserData>(
          future: _chooserFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const _ChooserData();
            return _ShopTypeDropdown(
              value: _shopType,
              shopTypes: data.shopTypes,
              onChanged: (value) => setState(() => _shopType = value),
            );
          },
        ),
        const SizedBox(height: 8),
        AuthConsentCheck(
          value: _terms,
          onChanged: (v) => setState(() => _terms = v),
          leading: 'Ich akzeptiere die ',
          linkLabel: 'AGB',
          trailing: ' *',
          onLinkTap: () => showLegalSheet(
            context,
            load: () =>
                LegalService(context.read<FirestoreService>()).loadTerms(),
          ),
        ),
        AuthConsentCheck(
          value: _privacy,
          onChanged: (v) => setState(() => _privacy = v),
          leading: 'Ich akzeptiere die ',
          linkLabel: 'Datenschutzhinweise',
          trailing: ' *',
          onLinkTap: () => showLegalSheet(
            context,
            load: () => LegalService(context.read<FirestoreService>())
                .loadPrivacyPolicy(),
          ),
        ),
        AuthCheck(
          value: _marketing,
          onChanged: (value) => setState(() => _marketing = value),
          labelKey: 'auth.acceptMarketing',
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          labelKey: 'auth.merchantRegister.button',
          onPressed: _register,
        ),
      ],
    );
  }
}

class _ChooserData {
  const _ChooserData({
    this.shopTypes = const [],
  });

  final List<String> shopTypes;
}

/// Theme-bewusstes Kategorie-Dropdown im Stil von [AuthTextField]: dunkler
/// Fill + dunkles Menü im Merchant-Dark-Theme (vorher fix hellgrau → „weißer
/// Kasten"), heller Fill im User-Theme.
class _ShopTypeDropdown extends StatelessWidget {
  const _ShopTypeDropdown({
    required this.value,
    required this.shopTypes,
    required this.onChanged,
  });

  final String? value;
  final List<String> shopTypes;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : AppColors.surfaceGray;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        dropdownColor: fill,
        iconEnabledColor: theme.colorScheme.onSurfaceVariant,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: texts.text('auth.shopType'),
          filled: true,
          fillColor: fill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        items: shopTypes
            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Adress-Eingabe über Geoapify-Autocomplete (dasselbe Tool wie im
/// Nutzer-Feed/Discover) statt vier freier Textfelder. Ein Treffer liefert
/// bereits Straße/Nr/PLZ/Stadt normalisiert — Registrierung geokodiert daraus
/// automatisch lat/lng ([AuthProvider._createMerchantDocuments]).
class _AddressPicker extends StatefulWidget {
  const _AddressPicker({required this.onPicked, this.initial});

  final ValueChanged<GeoResult> onPicked;
  final GeoResult? initial;

  @override
  State<_AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<_AddressPicker> {
  final _geo = GeoapifyService();
  final _query = TextEditingController();
  Timer? _debounce;
  List<GeoResult> _suggestions = const [];
  bool _loading = false;
  GeoResult? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      final res = await _geo.autocomplete(text, countryCode: 'de');
      if (!mounted) return;
      setState(() {
        _suggestions = res;
        _loading = false;
      });
    });
  }

  void _pick(GeoResult g) {
    setState(() {
      _picked = g;
      _suggestions = const [];
      _query.clear();
    });
    widget.onPicked(g);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill =
        isDark ? cs.surfaceContainerHigh : AppColors.surfaceGray;

    final picked = _picked;
    if (picked != null) {
      final summary = picked.formatted.isNotEmpty
          ? picked.formatted
          : [picked.street, picked.houseNumber, picked.postalCode, picked.city]
              .where((s) => s.isNotEmpty)
              .join(' ');
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.place_rounded, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _picked = null),
              child: const Text('Ändern'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _query,
            onChanged: _onChanged,
            decoration: InputDecoration(
              labelText: 'Adresse suchen',
              hintText: 'Straße, PLZ oder Stadt',
              filled: true,
              fillColor: fill,
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20, color: cs.onSurfaceVariant),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions
                    .map((g) => ListTile(
                          dense: true,
                          leading: Icon(Icons.place_outlined,
                              size: 18, color: cs.onSurfaceVariant),
                          title: Text(g.formatted,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurface)),
                          onTap: () => _pick(g),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
