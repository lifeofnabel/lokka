import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/widgets/userQrCard.dart';

/// Focused, calm QR screen: one card, one hint, light M3 surface.
class UserQrPage extends StatelessWidget {
  const UserQrPage({super.key, required this.card, required this.uid});

  final WalletCardModel card;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          card.merchantName,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Code kopieren',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: card.walletCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code kopiert'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              UserQrCard(card: card, uid: uid),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Halte diesen Code dem Scanner vor',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
