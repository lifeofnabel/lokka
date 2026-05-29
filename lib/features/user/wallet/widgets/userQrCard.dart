import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';

class UserQrCard extends StatelessWidget {
  const UserQrCard({
    super.key,
    required this.card,
    required this.uid,
  });

  final WalletCardModel card;
  final String uid;

  String get _qrPayload =>
      'lokka://wallet/$uid/${card.merchantId}/${card.walletCode}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: QrImageView(
              data: _qrPayload,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.transparent,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            card.walletCode,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
              letterSpacing: 4,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            card.merchantName,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.gray500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
