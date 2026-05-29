import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/widgets/userQrCard.dart';

class UserQrPage extends StatelessWidget {
  const UserQrPage({super.key, required this.card, required this.uid});

  final WalletCardModel card;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          card.merchantName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: card.walletCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Code kopiert'),
                  backgroundColor: AppColors.mintStrong,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              UserQrCard(card: card, uid: uid),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Halte diesen Code dem Scanner vor',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _WalletInfo(card: card),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletInfo extends StatelessWidget {
  const _WalletInfo({required this.card});

  final WalletCardModel card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wallet_rounded, size: 18, color: Colors.white38),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wallet-Karte',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
              Text(
                card.merchantShopType.isNotEmpty
                    ? '${card.merchantShopType} · ${card.merchantArea}'
                    : card.merchantArea,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
