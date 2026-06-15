import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/theme/appRadius.dart';
import '../../../core/theme/appSpacing.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';
import '../../merchant/tools/utils/linkOpener.dart';
import '../../merchant/tools/widgets/merchantToolUi.dart';
import '../models/merchantInviteModel.dart';
import '../providers/inviteProvider.dart';
import '../services/inviteService.dart';

class MerchantInvitePage extends StatelessWidget {
  const MerchantInvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => InviteProvider(
        service: InviteService(
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
    final provider = context.watch<InviteProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.invite.title'),
      subtitle: texts.text('merchant.invite.subtitle'),
      trailing: MerchantInfoTooltip(
        message: texts.text('merchant.invite.subtitle'),
      ),
      child: provider.isLoading
          ? const MerchantLoadingCards(count: 2)
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : Column(
                  children: [
                    if (provider.customerInvite != null)
                      _InviteCard(
                        title: texts.text('merchant.invite.customerTitle'),
                        subtitle: texts.text('merchant.invite.customerSubtitle'),
                        invite: provider.customerInvite!,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    if (provider.merchantInvite != null)
                      _InviteCard(
                        title: texts.text('merchant.invite.merchantTitle'),
                        subtitle: texts.text('merchant.invite.merchantSubtitle'),
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
  final MerchantInviteModel invite;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MerchantPremiumColors.line),
              ),
              child: Icon(
                invite.type == 'customer' ? Icons.person_add_alt_rounded : Icons.storefront_rounded,
                color: MerchantPremiumColors.ink,
              ),
            ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: MerchantPremiumColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: MerchantPremiumColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: MerchantPremiumColors.line),
            ),
            child: SelectableText(
              invite.inviteUrl,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: QrImageView(
              data: invite.inviteUrl,
              size: 140,
              backgroundColor: MerchantPremiumColors.surface,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(texts.text('merchant.invite.copied')),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(texts.text('merchant.invite.copy')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final text = Uri.encodeComponent(
                      "${texts.text('merchant.invite.shareText')} ${invite.inviteUrl}",
                    );
                    openExternalUrl('https://wa.me/?text=$text');
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(texts.text('merchant.invite.whatsapp')),
                  style: FilledButton.styleFrom(
                    backgroundColor: MerchantPremiumColors.ink,
                    foregroundColor: MerchantPremiumColors.base,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "${invite.openedCount} ${texts.text('merchant.invite.opens')} | ${invite.usedCount} ${texts.text('merchant.invite.used')}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
