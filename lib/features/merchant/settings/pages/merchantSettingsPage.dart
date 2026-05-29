import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantSettingsPage extends StatelessWidget {
  const MerchantSettingsPage({super.key});

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

class _MerchantShopView extends StatelessWidget {
  const _MerchantShopView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantShopProvider>();
    return MerchantToolScaffold(
      title: 'Shopdaten',
      subtitle: 'Diese Daten sehen Kunden in deinem oeffentlichen Profil.',
      trailing: const MerchantInfoTooltip(message: 'Diese Daten sehen Kunden in deinem oeffentlichen Profil.'),
      child: provider.isLoading
          ? const MerchantLoadingCards(count: 6)
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : const _ShopForm(),
    );
  }
}

class _ShopForm extends StatefulWidget {
  const _ShopForm();

  @override
  State<_ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<_ShopForm> {
  final shopName = TextEditingController();
  final businessName = TextEditingController();
  final description = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final street = TextEditingController();
  final houseNumber = TextEditingController();
  final postalCode = TextEditingController();
  final city = TextEditingController();
  final area = TextEditingController();
  final country = TextEditingController(text: 'Deutschland');
  final shopType = TextEditingController();
  final logoUrl = TextEditingController();
  final coverUrl = TextEditingController();
  final Map<String, TextEditingController> open = {};
  final Map<String, TextEditingController> close = {};
  final Map<String, bool> closed = {};
  bool isPublic = false;
  bool isActive = false;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    for (final day in _days) {
      open[day.key] = TextEditingController(text: '09:00');
      close[day.key] = TextEditingController(text: '18:00');
      closed[day.key] = false;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      shopName,
      businessName,
      description,
      email,
      phone,
      street,
      houseNumber,
      postalCode,
      city,
      area,
      country,
      shopType,
      logoUrl,
      coverUrl,
      ...open.values,
      ...close.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantShopProvider>();
    _fill(provider.merchant ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Basisdaten',
          children: [
            MerchantTextField(controller: shopName, label: 'Shopname'),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: businessName, label: 'Firmenname'),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: description, label: 'Beschreibung', maxLines: 3),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: email, label: 'E-Mail', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: phone, label: 'Telefon', keyboardType: TextInputType.phone),
          ],
        ),
        _SectionCard(
          title: 'Adresse',
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: MerchantTextField(controller: street, label: 'Strasse')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: MerchantTextField(controller: houseNumber, label: 'Nr.')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: MerchantTextField(controller: postalCode, label: 'PLZ')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: MerchantTextField(controller: city, label: 'Stadt')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: country, label: 'Land'),
          ],
        ),
        _SectionCard(
          title: 'Kategorie & Area',
          children: [
            MerchantTextField(controller: shopType, label: 'Kategorie'),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: area, label: 'Area'),
          ],
        ),
        _SectionCard(
          title: 'Oeffnungszeiten',
          children: _days
              .map(
                (day) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OpeningHoursRow(
                    label: day.label,
                    open: open[day.key]!,
                    close: close[day.key]!,
                    closed: closed[day.key] ?? false,
                    onClosedChanged: (value) => setState(() => closed[day.key] = value),
                  ),
                ),
              )
              .toList(),
        ),
        _SectionCard(
          title: 'Bilder',
          children: [
            _ImagePickerRow(
              title: 'Logo',
              imageUrl: logoUrl.text,
              onTap: () async {
                final uploaded = await provider.uploadImage();
                if (uploaded != null) setState(() => logoUrl.text = uploaded);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _ImagePickerRow(
              title: 'Cover',
              imageUrl: coverUrl.text,
              onTap: () async {
                final uploaded = await provider.uploadImage();
                if (uploaded != null) setState(() => coverUrl.text = uploaded);
              },
            ),
          ],
        ),
        _SectionCard(
          title: 'Sichtbarkeit',
          children: [
            SwitchListTile(
              value: isPublic,
              onChanged: (value) => setState(() => isPublic = value),
              title: const Text('Oeffentlich sichtbar'),
            ),
            SwitchListTile(
              value: isActive,
              onChanged: (value) => setState(() => isActive = value),
              title: const Text('Shop aktiv'),
            ),
          ],
        ),
        MerchantPrimaryButton(
          label: 'Shopdaten speichern',
          isLoading: provider.isSaving,
          onPressed: () => _save(context, provider),
        ),
      ],
    );
  }

  void _fill(Map<String, dynamic> data) {
    if (_filled) return;
    _filled = true;
    shopName.text = data['shopName']?.toString() ?? '';
    businessName.text = data['businessName']?.toString() ?? '';
    description.text = data['description']?.toString() ?? '';
    email.text = data['email']?.toString() ?? '';
    phone.text = data['phone']?.toString() ?? '';
    street.text = data['street']?.toString() ?? '';
    houseNumber.text = data['houseNumber']?.toString() ?? '';
    postalCode.text = data['postalCode']?.toString() ?? '';
    city.text = data['city']?.toString() ?? '';
    area.text = data['area']?.toString() ?? '';
    country.text = data['country']?.toString() ?? 'Deutschland';
    shopType.text = data['shopType']?.toString() ?? '';
    logoUrl.text = data['logoUrl']?.toString() ?? '';
    coverUrl.text = data['coverUrl']?.toString() ?? '';
    isPublic = data['isPublic'] as bool? ?? false;
    isActive = data['isActive'] as bool? ?? false;

    final hours = data['openingHours'];
    if (hours is Map) {
      for (final day in _days) {
        final dayData = hours[day.key];
        if (dayData is Map) {
          open[day.key]?.text = dayData['open']?.toString() ?? '09:00';
          close[day.key]?.text = dayData['close']?.toString() ?? '18:00';
          closed[day.key] = dayData['closed'] as bool? ?? false;
        }
      }
    }
  }

  Future<void> _save(BuildContext context, MerchantShopProvider provider) async {
    if (shopName.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        shopType.text.trim().isEmpty ||
        area.text.trim().isEmpty ||
        street.text.trim().isEmpty ||
        houseNumber.text.trim().isEmpty ||
        postalCode.text.trim().isEmpty ||
        city.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte fuelle Shopname, Adresse, Telefon, Kategorie und Area aus.')));
      return;
    }

    await provider.save({
      'shopName': shopName.text.trim(),
      'businessName': businessName.text.trim().isEmpty ? shopName.text.trim() : businessName.text.trim(),
      'description': description.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
      'street': street.text.trim(),
      'houseNumber': houseNumber.text.trim(),
      'postalCode': postalCode.text.trim(),
      'city': city.text.trim(),
      'area': area.text.trim(),
      'country': country.text.trim().isEmpty ? 'Deutschland' : country.text.trim(),
      'shopType': shopType.text.trim(),
      'logoUrl': logoUrl.text.trim(),
      'coverUrl': coverUrl.text.trim(),
      'openingHours': {
        for (final day in _days)
          day.key: {
            'open': open[day.key]?.text.trim() ?? '',
            'close': close[day.key]?.text.trim() ?? '',
            'closed': closed[day.key] ?? false,
          },
      },
      'isPublic': isPublic,
      'isActive': isActive,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shopdaten gespeichert.')));
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _OpeningHoursRow extends StatelessWidget {
  const _OpeningHoursRow({
    required this.label,
    required this.open,
    required this.close,
    required this.closed,
    required this.onClosedChanged,
  });

  final String label;
  final TextEditingController open;
  final TextEditingController close;
  final bool closed;
  final ValueChanged<bool> onClosedChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900))),
            Switch(value: closed, onChanged: onClosedChanged),
            const Text('Geschlossen'),
          ],
        ),
        if (!closed)
          Row(
            children: [
              Expanded(child: MerchantTextField(controller: open, label: 'Von')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: MerchantTextField(controller: close, label: 'Bis')),
            ],
          ),
      ],
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isEmpty ? const Icon(Icons.image_rounded) : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
            const Icon(Icons.upload_rounded),
          ],
        ),
      ),
    );
  }
}

class _Day {
  const _Day(this.key, this.label);

  final String key;
  final String label;
}

const _days = [
  _Day('monday', 'Montag'),
  _Day('tuesday', 'Dienstag'),
  _Day('wednesday', 'Mittwoch'),
  _Day('thursday', 'Donnerstag'),
  _Day('friday', 'Freitag'),
  _Day('saturday', 'Samstag'),
  _Day('sunday', 'Sonntag'),
];
