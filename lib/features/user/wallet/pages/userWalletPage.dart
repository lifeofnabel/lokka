import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/pages/userWalletDetailPage.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/widgets/walletCard.dart';

class UserWalletPage extends StatelessWidget {
  const UserWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserWalletProvider>(
      builder: (context, provider, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            expandedHeight: 60,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Wallet',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.error != null)
            const SliverFillRemaining(child: _WalletErrorView())
          else if (provider.cards.isEmpty)
            const SliverFillRemaining(child: _WalletEmptyView())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: provider.cards.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (ctx, i) {
                  final card = provider.cards[i];
                  return WalletCard(
                    card: card,
                    onTap: () => _openDetail(ctx, card),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, WalletCardModel card) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserWalletDetailPage(card: card, uid: uid),
      ),
    );
  }
}

class _WalletEmptyView extends StatelessWidget {
  const _WalletEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wallet_outlined, size: 72, color: AppColors.gray300),
        SizedBox(height: AppSpacing.md),
        Text(
          'Noch keine Karten gespeichert',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.gray500,
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'Besuche einen Partner und füge ihn zu deiner Wallet hinzu.',
            style: TextStyle(fontSize: 14, color: AppColors.gray300),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _WalletErrorView extends StatelessWidget {
  const _WalletErrorView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.gray300),
        SizedBox(height: AppSpacing.md),
        Text(
          'Wallet konnte nicht geladen werden',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.gray500,
          ),
        ),
      ],
    );
  }
}
