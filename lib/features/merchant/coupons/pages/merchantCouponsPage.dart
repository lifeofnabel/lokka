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
import '../models/couponModel.dart';
import '../providers/merchantCouponsProvider.dart';
import '../services/merchantCouponsService.dart';
import '../widgets/couponCard.dart';

class MerchantCouponsPage extends StatelessWidget {
  const MerchantCouponsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantCouponsProvider(
        service: MerchantCouponsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantCouponsView(),
    );
  }
}

class _MerchantCouponsView extends StatelessWidget {
  const _MerchantCouponsView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantCouponsProvider>();
    return MerchantToolScaffold(
      title: texts.text('merchant.coupons.title'),
      subtitle: texts.text('merchant.coupons.subtitle'),
      backPath: '/merchant/dashboard',
      trailing: MerchantInfoTooltip(
        message: texts.text('merchant.coupons.tooltip'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: texts.text('merchant.coupons.create'),
            icon: Icons.add_rounded,
            onPressed: () => context.push('/merchant/coupons/edit'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards(count: 5)
          else if (provider.error != null)
            MerchantErrorState(
              message: provider.error!,
              onRetry: provider.load,
            )
          else if (provider.coupons.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.coupons.emptyTitle'),
              message: texts.text('merchant.coupons.emptyMessage'),
              actionLabel: texts.text('merchant.coupons.create'),
              onAction: () => context.push('/merchant/coupons/edit'),
            )
          else
            ...provider.coupons.map(
              (coupon) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CouponCard(
                  coupon: coupon,
                  onEdit: () => context.push('/merchant/coupons/edit/${coupon.id}'),
                  onPublish: () => _publish(context, provider, coupon),
                  onPause: () => provider.pauseCoupon(coupon.id),
                  onArchive: () => _confirm(
                    context: context,
                    titleKey: 'merchant.coupons.archiveTitle',
                    messageKey: 'merchant.coupons.archiveMessage',
                    onAccepted: () => provider.archiveCoupon(coupon.id),
                  ),
                  onDeleteDraft: () => _confirm(
                    context: context,
                    titleKey: 'merchant.coupons.deleteTitle',
                    messageKey: 'merchant.coupons.deleteMessage',
                    onAccepted: () => provider.deleteDraftCoupon(coupon.id),
                    danger: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _publish(
    BuildContext context,
    MerchantCouponsProvider provider,
    CouponModel coupon,
  ) async {
    final accepted = await _confirm(
      context: context,
      titleKey: 'merchant.coupons.publishTitle',
      messageKey: 'merchant.coupons.publishMessage',
    );
    if (accepted != true) return;
    // publishCoupon patcht den Coupon lokal – kein voller Reload nötig.
    await provider.publishCoupon(coupon);
  }
}

Future<bool?> _confirm({
  required BuildContext context,
  required String titleKey,
  required String messageKey,
  Future<void> Function()? onAccepted,
  bool danger = false,
}) {
  final texts = context.read<LanguageService>();
  return showMerchantBottomSheet<bool>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          texts.text(titleKey),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MerchantPremiumColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          texts.text(messageKey),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () async {
            if (onAccepted != null) await onAccepted();
            if (sheetContext.mounted) Navigator.of(sheetContext).pop(true);
          },
          style: FilledButton.styleFrom(
            backgroundColor: danger ? MerchantPremiumColors.danger : MerchantPremiumColors.ink,
            foregroundColor: danger ? MerchantPremiumColors.ink : MerchantPremiumColors.base,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(danger ? texts.text('common.delete') : texts.text('common.ok')),
        ),
        TextButton(
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: Text(texts.text('common.cancel')),
        ),
      ],
    ),
  );
}
