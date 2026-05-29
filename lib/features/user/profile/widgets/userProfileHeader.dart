import 'package:flutter/material.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';

class UserProfileHeader extends StatelessWidget {
  const UserProfileHeader({
    super.key,
    required this.user,
    required this.walletCount,
    required this.rewardsCount,
    required this.couponsCount,
  });

  final AppUserModel user;
  final int walletCount;
  final int rewardsCount;
  final int couponsCount;

  String get _initials {
    final first = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final last = user.lastName.isNotEmpty ? user.lastName[0] : '';
    return (first + last).toUpperCase();
  }

  String get _displayName => '${user.firstName} ${user.lastName}'.trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.black,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initials.isEmpty ? '?' : _initials,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _displayName.isEmpty ? 'Kein Name' : _displayName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatItem(
              value: '$walletCount',
              label: 'Wallet',
              icon: Icons.wallet_rounded,
            ),
            const SizedBox(width: AppSpacing.xl),
            _StatItem(
              value: '$rewardsCount',
              label: 'Belohnungen',
              icon: Icons.card_giftcard_rounded,
            ),
            const SizedBox(width: AppSpacing.xl),
            _StatItem(
              value: '$couponsCount',
              label: 'Coupons',
              icon: Icons.local_offer_rounded,
            ),
          ],
        ),
        if (user.customerCode.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag_rounded, size: 16, color: AppColors.gray500),
                const SizedBox(width: 6),
                Text(
                  user.customerCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.gray500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
