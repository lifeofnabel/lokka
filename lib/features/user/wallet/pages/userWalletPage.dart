import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/pages/userWalletDetailPage.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/widgets/walletCard.dart';

class UserWalletPage extends StatelessWidget {
  const UserWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Consumer<UserWalletProvider>(
      builder: (context, provider, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.surfaceBg,
            surfaceTintColor: AppColors.surfaceBg,
            elevation: 0,
            expandedHeight: 60,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Wallet',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          if (provider.isLoading)
            const SliverFillRemaining(child: AppLoadingState())
          else if (provider.error != null)
            const SliverFillRemaining(
              child: AppErrorState(
                message: 'Wallet konnte nicht geladen werden',
              ),
            )
          else if (provider.cards.isEmpty)
            const SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.wallet_outlined,
                title: 'Noch keine Karten gespeichert',
                message:
                    'Besuche einen Partner und füge ihn zu deiner Wallet hinzu.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: provider.cards.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
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

