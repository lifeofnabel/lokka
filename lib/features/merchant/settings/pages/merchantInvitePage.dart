import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/utils/linkOpener.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantInvitePage extends StatelessWidget {
  const MerchantInvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantInviteProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantInviteView(),
    );
  }
}

class _MerchantInviteView extends StatelessWidget {
  const _MerchantInviteView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantInviteProvider>();
    return MerchantToolScaffold(
      title: 'Einladen',
      subtitle: 'Teile deinen persoenlichen Link mit Kunden oder anderen Geschaeften.',
      trailing: const MerchantInfoTooltip(message: 'Teile deinen persoenlichen Link mit Kunden oder anderen Geschaeften.'),
      child: provider.isLoading
          ? const MerchantLoadingCards(count: 2)
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : Column(
                  children: [
                    if (provider.customerInvite != null)
                      _InviteCard(
                        title: 'Kunden einladen',
                        subtitle: 'Teile deine Kundenkarte und bringe Menschen in deine Wallet.',
                        invite: provider.customerInvite!,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    if (provider.merchantInvite != null)
                      _InviteCard(
                        title: 'Haendler einladen',
                        subtitle: 'Empfiehl Lokka an andere lokale Geschaefte.',
                        invite: provider.merchantInvite!,
                      ),
                  ],
                ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.title,
    required this.subtitle,
    required this.invite,
  });

  final String title;
  final String subtitle;
  final MerchantInviteData invite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(20)),
                child: Icon(invite.type == 'customer' ? Icons.person_add_alt_rounded : Icons.storefront_rounded),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.gray700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(AppRadius.large)),
            child: SelectableText(invite.inviteUrl, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: QrImageView(
              data: invite.inviteUrl,
              size: 140,
              backgroundColor: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: invite.inviteUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link kopiert.')));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Link kopieren'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final text = Uri.encodeComponent('Schau dir Lokka an: ${invite.inviteUrl}');
                    openExternalUrl('https://wa.me/?text=$text');
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('WhatsApp'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.black, foregroundColor: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${invite.openedCount} Oeffnungen · ${invite.usedCount} genutzt',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
