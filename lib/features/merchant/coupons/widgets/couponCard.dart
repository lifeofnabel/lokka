import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: AppColors.white,
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
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(texts, coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.gray700,
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
    return ActionChip(
      avatar: Icon(
        icon,
        size: 17,
        color: isDanger ? Colors.red.shade700 : AppColors.black,
      ),
      label: Text(label),
      onPressed: onTap,
      labelStyle: TextStyle(
        color: isDanger ? Colors.red.shade700 : AppColors.black,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: AppColors.gray50,
      side: BorderSide(color: isDanger ? Colors.red.shade100 : AppColors.border),
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
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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
