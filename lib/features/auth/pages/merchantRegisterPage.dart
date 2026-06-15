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
  final _areaFallback = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  String? _shopType;
  String? _area;
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
    _areaFallback.dispose();
    super.dispose();
  }

  Future<_ChooserData> _loadChooser() async {
    final provider = context.read<AuthProvider>();
    final areas = await provider.loadAreas();
    final shopTypes = await provider.loadShopTypes();
    return _ChooserData(areas: areas, shopTypes: shopTypes);
  }

  Future<void> _register() async {
    final texts = context.read<LanguageService>();
    final shopType = (_customShopType.text.trim().isNotEmpty)
        ? _customShopType.text.trim()
        : (_shopType ?? '');
    final area = _area ?? _areaFallback.text;
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
      area,
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
            area: area,
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
            area: area,
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
              AuthTextField(controller: _shopName, labelKey: 'auth.shopName'),
              AuthTextField(controller: _firstName, labelKey: 'auth.ownerFirstName'),
              AuthTextField(controller: _lastName, labelKey: 'auth.ownerLastName'),
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
              AuthTextField(controller: _phone, labelKey: 'auth.phone'),
              _AddressCard(
                street: _street,
                houseNumber: _houseNumber,
                postalCode: _postalCode,
                city: _city,
              ),
              FutureBuilder<_ChooserData>(
                future: _chooserFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? const _ChooserData();
                  return Column(
                    children: [
                      if (data.shopTypes.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _shopType,
                          decoration: _authDropdownDecoration(
                            context.watch<LanguageService>().text('auth.shopType'),
                          ),
                          items: data.shopTypes
                              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                              .toList(),
                          onChanged: (value) => setState(() => _shopType = value),
                        )
                      else
                        AuthTextField(
                          controller: _customShopType,
                          labelKey: 'auth.shopType',
                        ),
                      if (data.shopTypes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _customShopType,
                          labelKey: 'auth.customShopType',
                        ),
                      ],
                      if (data.areas.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _area,
                          decoration: _authDropdownDecoration(
                            context.watch<LanguageService>().text('auth.area'),
                          ),
                          items: data.areas
                              .map((area) => DropdownMenuItem(value: area, child: Text(area)))
                              .toList(),
                          onChanged: (value) => setState(() => _area = value),
                        )
                      else
                        AuthTextField(
                          controller: _areaFallback,
                          labelKey: 'auth.area',
                        ),
                    ],
                  );
                },
              ),
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
    this.areas = const [],
    this.shopTypes = const [],
  });

  final List<String> areas;
  final List<String> shopTypes;
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.street,
    required this.houseNumber,
    required this.postalCode,
    required this.city,
  });

  final TextEditingController street;
  final TextEditingController houseNumber;
  final TextEditingController postalCode;
  final TextEditingController city;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth > 360;
        final streetField = AuthTextField(controller: street, labelKey: 'auth.street');
        final houseField = AuthTextField(controller: houseNumber, labelKey: 'auth.houseNumber');
        final postalField = AuthTextField(controller: postalCode, labelKey: 'auth.postalCode');
        final cityField = AuthTextField(controller: city, labelKey: 'auth.city');

        Widget pair(Widget first, Widget second, {int firstFlex = 2}) {
          if (!twoColumns) {
            return Column(children: [first, second]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: firstFlex, child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          );
        }

        final cs = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceGray,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              pair(streetField, houseField, firstFlex: 3),
              pair(postalField, cityField),
            ],
          ),
        );
      },
    );
  }
}

/// Filled M3 decoration matching [AuthTextField] for inline dropdowns.
InputDecoration _authDropdownDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surfaceGray,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}
