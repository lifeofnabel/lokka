import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/couponModel.dart';

class CouponCard extends StatelessWidget {
  const CouponCard({
    super.key,
    required this.coupon,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onArchive,
    required this.onDeleteDraft,
  });

  final CouponModel coupon;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onPause;
  final VoidCallback onArchive;
  final VoidCallback onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.ink,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: MerchantPremiumColors.gold,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.title.isEmpty
                          ? texts.text('merchant.coupons.untitled')
                          : coupon.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(texts, coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: _statusLabel(texts, coupon.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniAction(
                label: texts.text('common.edit'),
                icon: Icons.edit_rounded,
                onTap: onEdit,
              ),
              if (coupon.isDraft || coupon.isPaused)
                _MiniAction(
                  label: texts.text('merchant.coupons.publish'),
                  icon: Icons.rocket_launch_rounded,
                  onTap: onPublish,
                ),
              if (coupon.isLive)
                _MiniAction(
                  label: texts.text('merchant.coupons.pause'),
                  icon: Icons.pause_rounded,
                  onTap: onPause,
                ),
              if (!coupon.isArchivedCoupon)
                _MiniAction(
                  label: texts.text('merchant.coupons.archive'),
                  icon: Icons.archive_rounded,
                  onTap: onArchive,
                ),
              if (coupon.isDraft)
                _MiniAction(
                  label: texts.text('common.delete'),
                  icon: Icons.delete_outline_rounded,
                  isDanger: true,
                  onTap: onDeleteDraft,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final foreground =
        isDanger ? MerchantPremiumColors.danger : MerchantPremiumColors.ink;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: foreground),
      label: Text(label),
      onPressed: onTap,
      labelStyle: TextStyle(
        color: foreground,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor:
          isDanger ? MerchantPremiumColors.dangerSoft : MerchantPremiumColors.surfaceAlt,
      side: BorderSide(
        color: isDanger ? MerchantPremiumColors.danger : MerchantPremiumColors.line,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _subtitle(LanguageService texts, CouponModel coupon) {
  final type = texts.text('merchant.coupons.type.${coupon.type}');
  final count = coupon.codes.length;
  return '$type | $count ${texts.text('merchant.coupons.codes')}';
}

String _statusLabel(LanguageService texts, String status) {
  return switch (status) {
    CouponStatus.active => texts.text('merchant.coupons.status.active'),
    CouponStatus.paused => texts.text('merchant.coupons.status.paused'),
    CouponStatus.archived => texts.text('merchant.coupons.status.archived'),
    _ => texts.text('merchant.coupons.status.draft'),
  };
}
