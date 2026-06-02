import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/pointsSystemModel.dart';
import '../providers/merchantPointsProvider.dart';
import '../services/merchantPointsService.dart';
import '../widgets/pointsRuleCard.dart';

class MerchantPointsPage extends StatelessWidget {
  const MerchantPointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantPointsProvider(
        service: MerchantPointsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantPointsView(),
    );
  }
}

class _MerchantPointsView extends StatelessWidget {
  const _MerchantPointsView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantPointsProvider>();

    return MerchantToolScaffold(
      title: texts.text('merchant.points.title'),
      subtitle: texts.text('merchant.points.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.points.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CreditNotice(texts: texts),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards(count: 5)
          else if (provider.error != null && provider.systems.isEmpty && provider.rewards.isEmpty)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else ...[
            _SectionHeader(
              title: texts.text('merchant.points.systemSection'),
              actionLabel: provider.systems.isEmpty ? texts.text('merchant.points.createSystem') : texts.text('common.edit'),
              onAction: () {
                final target = provider.activeSystem ?? (provider.systems.isNotEmpty ? provider.systems.first : null);
                if (target == null) {
                  context.push('/merchant/points/system/edit');
                } else {
                  context.push('/merchant/points/system/edit/${target.id}');
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (provider.systems.isEmpty)
              MerchantEmptyState(
                title: texts.text('merchant.points.emptyTitle'),
                message: texts.text('merchant.points.emptyMessage'),
                actionLabel: texts.text('merchant.points.createSystem'),
                onAction: () => context.push('/merchant/points/system/edit'),
              )
            else
              ...provider.systems.map(
                (system) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PointsSystemCard(
                    system: system,
                    onEdit: () => context.push('/merchant/points/system/edit/${system.id}'),
                    onPublish: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.activateSystemTitle',
                      messageKey: 'merchant.points.activateSystemMessage',
                      confirmKey: 'merchant.points.activate',
                      onConfirm: () async {
                        await provider.publishSystem(system);
                      },
                    ),
                    onPause: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.pauseSystemTitle',
                      messageKey: 'merchant.points.pauseSystemMessage',
                      confirmKey: 'merchant.points.pause',
                      onConfirm: () => provider.pauseSystem(system.id),
                    ),
                    onArchive: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.archiveSystemTitle',
                      messageKey: 'merchant.points.archiveSystemMessage',
                      confirmKey: 'merchant.points.archive',
                      onConfirm: () => provider.archiveSystem(system.id),
                    ),
                    onDeleteDraft: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.deleteSystemTitle',
                      messageKey: 'merchant.points.deleteSystemMessage',
                      confirmKey: 'common.delete',
                      isDanger: true,
                      onConfirm: () => provider.deleteDraftSystem(system.id),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(
              title: texts.text('merchant.points.rewardsSection'),
              actionLabel: texts.text('merchant.points.createReward'),
              onAction: () => context.push('/merchant/points/rewards/edit'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (provider.rewards.isEmpty)
              MerchantEmptyState(
                title: texts.text('merchant.points.rewardsEmptyTitle'),
                message: texts.text('merchant.points.rewardsEmptyMessage'),
                actionLabel: texts.text('merchant.points.createReward'),
                onAction: () => context.push('/merchant/points/rewards/edit'),
              )
            else
              ...provider.rewards.map(
                (reward) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PointsRewardCard(
                    reward: reward,
                    onEdit: () => context.push('/merchant/points/rewards/edit/${reward.id}'),
                    onPublish: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.activateRewardTitle',
                      messageKey: 'merchant.points.activateRewardMessage',
                      confirmKey: 'merchant.points.activate',
                      onConfirm: () async {
                        await provider.publishReward(reward);
                      },
                    ),
                    onPause: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.pauseRewardTitle',
                      messageKey: 'merchant.points.pauseRewardMessage',
                      confirmKey: 'merchant.points.pause',
                      onConfirm: () => provider.pauseReward(reward.id),
                    ),
                    onArchive: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.archiveRewardTitle',
                      messageKey: 'merchant.points.archiveRewardMessage',
                      confirmKey: 'merchant.points.archive',
                      onConfirm: () => provider.archiveReward(reward.id),
                    ),
                    onDeleteDraft: () => _confirmAction(
                      context,
                      titleKey: 'merchant.points.deleteRewardTitle',
                      messageKey: 'merchant.points.deleteRewardMessage',
                      confirmKey: 'common.delete',
                      isDanger: true,
                      onConfirm: () => provider.deleteDraftReward(reward.id),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CreditNotice extends StatelessWidget {
  const _CreditNotice({required this.texts});

  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.credit_score_rounded, color: AppColors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              texts.text('merchant.points.creditHint'),
              style: const TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

Future<void> _confirmAction(
  BuildContext context, {
  required String titleKey,
  required String messageKey,
  required String confirmKey,
  required Future<void> Function() onConfirm,
  bool isDanger = false,
}) async {
  final texts = context.read<LanguageService>();
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text(messageKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gray700,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isDanger ? Colors.red.shade700 : AppColors.black,
                foregroundColor: AppColors.white,
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
