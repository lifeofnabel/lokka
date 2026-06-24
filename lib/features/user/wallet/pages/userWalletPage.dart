import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/widgets/walletCard.dart';
import 'package:lokka/features/user/wallet/widgets/walletCardStack.dart';

class UserWalletPage extends StatelessWidget {
  const UserWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    return Consumer<UserWalletProvider>(
      builder: (context, provider, _) {
        final count = provider.cards.length;
        final subtitle = provider.isLoading
            ? 'Deine Karten an einem Ort'
            : count == 0
                ? 'Deine Partner-Karten an einem Ort'
                : '$count ${count == 1 ? 'Karte' : 'Karten'} gespeichert';
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.mintGradient,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet',
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    uid: uid,
                    onTap: () => openWalletCardStack(ctx, card, uid),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        );
      },
    );
  }
}

