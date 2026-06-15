import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';

/// Focused QR card: light surface, soft elevation, high-contrast code modules.
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: _qrPayload,
            version: QrVersions.auto,
            size: 248,
            backgroundColor: Colors.transparent,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.onSurfaceDark,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.onSurfaceDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            card.walletCode,
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            card.merchantName,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
