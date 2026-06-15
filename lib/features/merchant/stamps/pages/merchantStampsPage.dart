import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/stampCardModel.dart';
import '../providers/merchantStampsProvider.dart';
import '../services/merchantStampsService.dart';
import '../widgets/merchantStampCard.dart';

class MerchantStampsPage extends StatelessWidget {
  const MerchantStampsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantStampsProvider(
        service: MerchantStampsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantStampsView(),
    );
  }
}

class _MerchantStampsView extends StatelessWidget {
  const _MerchantStampsView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantStampsProvider>();

    return MerchantToolScaffold(
      title: texts.text('merchant.stamps.title'),
      subtitle: texts.text('merchant.stamps.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.stamps.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IntroNotice(texts: texts),
          const SizedBox(height: AppSpacing.md),
          MerchantPrimaryButton(
            label: texts.text('merchant.stamps.create'),
            icon: Icons.add_rounded,
            isLoading: provider.isSaving,
            onPressed: () => context.push('/merchant/stamps/edit'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards(count: 4)
          else if (provider.error != null && provider.cards.isEmpty)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else if (provider.cards.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.stamps.emptyTitle'),
              message: texts.text('merchant.stamps.emptyMessage'),
              actionLabel: texts.text('merchant.stamps.create'),
              onAction: () => context.push('/merchant/stamps/edit'),
            )
          else
            ...provider.cards.map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: MerchantStampCard(
                  card: card,
                  onEdit: () => context.push('/merchant/stamps/edit/${card.id}'),
                  onPublish: () => _publish(context, card),
                  onPause: () => _confirmAction(
                    context,
                    titleKey: 'merchant.stamps.pauseTitle',
                    messageKey: 'merchant.stamps.pauseMessage',
                    confirmKey: 'merchant.stamps.pause',
                    onConfirm: () => provider.pauseCard(card.id),
                  ),
                  onArchive: () => _confirmAction(
                    context,
                    titleKey: 'merchant.stamps.archiveTitle',
                    messageKey: 'merchant.stamps.archiveMessage',
                    confirmKey: 'merchant.stamps.archive',
                    onConfirm: () => provider.archiveCard(card.id),
                  ),
                  onDeleteDraft: () => _confirmAction(
                    context,
                    titleKey: 'merchant.stamps.deleteTitle',
                    messageKey: 'merchant.stamps.deleteMessage',
                    confirmKey: 'common.delete',
                    isDanger: true,
                    onConfirm: () => provider.deleteDraftCard(card.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _publish(BuildContext context, StampCardModel card) async {
    final provider = context.read<MerchantStampsProvider>();
    await _confirmAction(
      context,
      titleKey: 'merchant.stamps.publishTitle',
      message: kStampPublishMessage,
      confirmKey: 'merchant.stamps.publish',
      onConfirm: () async {
        await provider.publishCard(card);
      },
    );
  }
}

/// Lokale, kostenlose Hinweistexte (kein Credit-/Preis-Bezug mehr).
const String kStampPublishMessage =
    'Nach der Bestätigung wird die Karte sofort für deine Kundinnen und Kunden aktiv.';
const String kStampIntroMessage =
    'Erstelle eine digitale Stempelkarte, die Gäste gern vollmachen. Du entscheidest über Bedingung, Belohnung und Look – ganz ohne zusätzliche Kosten.';

class _IntroNotice extends StatelessWidget {
  const _IntroNotice({required this.texts});

  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: MerchantPremiumColors.surfaceAlt,
      radius: 26,
      child: Row(
        children: [
          const MerchantPremiumIconBox(
            icon: Icons.loyalty_rounded,
            size: 46,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              kStampIntroMessage,
              style: const TextStyle(
                color: MerchantPremiumColors.mutedLight,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmAction(
  BuildContext context, {
  required String titleKey,
  String? messageKey,
  String? message,
  required String confirmKey,
  required Future<void> Function() onConfirm,
  bool isDanger = false,
}) async {
  final texts = context.read<LanguageService>();
  final resolvedMessage = message ?? (messageKey != null ? texts.text(messageKey) : '');
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              texts.text(titleKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              resolvedMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isDanger ? MerchantPremiumColors.danger : MerchantPremiumColors.ink,
                foregroundColor: isDanger ? Colors.white : MerchantPremiumColors.base,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(texts.text(confirmKey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text(texts.text('common.cancel')),
            ),
          ],
        ),
      ),
    ),
  );

  if (accepted != true || !context.mounted) return;
  await onConfirm();
}
