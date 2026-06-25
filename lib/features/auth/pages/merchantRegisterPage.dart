import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
import '../providers/authProvider.dart';
import '../services/authNavigation.dart';
import '../widgets/authFlowWidgets.dart';

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
  final _customShopType = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  String? _shopType;
  String? _localError;
  late Future<_ChooserData> _chooserFuture;

  bool get _isGoogleCompletion => context.read<AuthProvider>().currentUser != null;

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
    _customShopType.dispose();
    super.dispose();
  }

  Future<_ChooserData> _loadChooser() async {
    final provider = context.read<AuthProvider>();
    final shopTypes = await provider.loadShopTypes();
    return _ChooserData(shopTypes: shopTypes);
  }

  Future<void> _register() async {
    final texts = context.read<LanguageService>();
    final shopType = (_customShopType.text.trim().isNotEmpty)
        ? _customShopType.text.trim()
        : (_shopType ?? '');
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
            phone: _phone.text,
            street: _street.text,
            houseNumber: _houseNumber.text,
            postalCode: _postalCode.text,
            city: _city.text,
            shopType: shopType,
            customShopType: _customShopType.text,
          )
        : await provider.registerMerchant(
            shopName: _shopName.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            password: _password.text,
            phone: _phone.text,
            street: _street.text,
            houseNumber: _houseNumber.text,
            postalCode: _postalCode.text,
            city: _city.text,
            shopType: shopType,
            customShopType: _customShopType.text,
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
              AuthTextField(controller: _phone, labelKey: 'auth.phone'),
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
              AuthFieldRow(
                firstFlex: 3,
                secondFlex: 1,
                first:
                    AuthTextField(controller: _street, labelKey: 'auth.street'),
                second: AuthTextField(
                    controller: _houseNumber, labelKey: 'auth.houseNumber'),
              ),
              AuthFieldRow(
                firstFlex: 2,
                secondFlex: 3,
                first: AuthTextField(
                    controller: _postalCode, labelKey: 'auth.postalCode'),
                second: AuthTextField(controller: _city, labelKey: 'auth.city'),
              ),
              const AuthSectionLabel(labelKey: 'auth.section.category'),
              FutureBuilder<_ChooserData>(
                future: _chooserFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? const _ChooserData();
                  return Column(
                    children: [
                      if (data.shopTypes.isNotEmpty)
                        _ShopTypeDropdown(
                          value: _shopType,
                          shopTypes: data.shopTypes,
                          onChanged: (value) =>
                              setState(() => _shopType = value),
                        )
                      else
                        AuthTextField(
                          controller: _customShopType,
                          labelKey: 'auth.shopType',
                        ),
                      if (data.shopTypes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        AuthTextField(
                          controller: _customShopType,
                          labelKey: 'auth.customShopType',
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              AuthCheck(
                value: _terms,
                onChanged: (value) => setState(() => _terms = value),
                labelKey: 'auth.acceptTerms',
              ),
              AuthCheck(
                value: _privacy,
                onChanged: (value) => setState(() => _privacy = value),
                labelKey: 'auth.acceptPrivacy',
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
