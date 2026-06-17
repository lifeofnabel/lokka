import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import 'publicShopTheme.dart';

/// Fuß der Kundensicht: nur noch das Impressum. Kontakt-Buttons und
/// Öffnungszeiten sitzen jetzt im Cover-Bereich (PublicShopContactRail).
class PublicShopFooter extends StatelessWidget {
  const PublicShopFooter({
    super.key,
    required this.merchant,
    required this.palette,
  });

  final Map<String, dynamic> merchant;
  final PublicShopPalette palette;

  String _str(String key) => (merchant[key] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final shopName = _str('shopName').isNotEmpty ? _str('shopName') : _str('businessName');
    final owner = _str('ownerName');
    final address = _str('fullAddress').isNotEmpty ? _str('fullAddress') : _str('address');
    final phone = _str('phone');
    final email = _str('email');

    final lines = <(String, String)>[
      if (shopName.isNotEmpty) (texts.text('public.shop.impressumBusiness'), shopName),
      if (owner.isNotEmpty) (texts.text('public.shop.impressumOwner'), owner),
      if (address.isNotEmpty) (texts.text('public.shop.impressumAddress'), address),
      if (phone.isNotEmpty) (texts.text('public.shop.impressumPhone'), phone),
      if (email.isNotEmpty) (texts.text('public.shop.impressumEmail'), email),
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texts.text('public.shop.impressumTitle'),
            style: TextStyle(color: palette.ink, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Text(
              texts.text('public.shop.impressumMissing'),
              style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700, fontSize: 13),
            )
          else
            for (final (label, value) in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        label,
                        style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(color: palette.ink, fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
