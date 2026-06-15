import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';
import 'package:lokka/features/user/wallet/models/pointsProgressModel.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';
import 'package:lokka/features/user/wallet/widgets/walletDetailHeader.dart';
import 'package:lokka/features/user/wallet/widgets/stampProgressCard.dart';
import 'package:lokka/features/user/wallet/widgets/pointsProgressCard.dart';

class UserWalletDetailPage extends StatefulWidget {
  const UserWalletDetailPage({
    super.key,
    required this.card,
    required this.uid,
  });

  final WalletCardModel card;
  final String uid;

  @override
  State<UserWalletDetailPage> createState() => _UserWalletDetailPageState();
}

class _UserWalletDetailPageState extends State<UserWalletDetailPage> {
  late final UserWalletService _service;
  late final FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _service = UserWalletService(
      firestoreService: _firestoreService,
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: Column(
        children: [
          WalletDetailHeader(card: widget.card),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QrSection(card: widget.card, uid: widget.uid),
                  if (widget.card.hasPoints)
                    StreamBuilder<PointsProgressModel?>(
                      stream: _service.pointsProgressByMerchantStream(
                          widget.card.merchantId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _LoadingRow();
                        }
                        final pts = snapshot.data;
                        // No points yet => render nothing (no empty card).
                        if (pts == null) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.lg),
                            const _SectionTitle('Punkte'),
                            const SizedBox(height: AppSpacing.md),
                            PointsProgressCard(
                              progress: pts,
                              merchantName: widget.card.merchantName,
                            ),
                          ],
                        );
                      },
                    ),
                  if (widget.card.hasStampCards)
                    StreamBuilder<List<StampProgressModel>>(
                      stream: _service.stampProgressByMerchantStream(
                          widget.card.merchantId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _LoadingRow();
                        }
                        final stamps = snapshot.data ?? [];
                        // No stamp cards yet => render nothing.
                        if (stamps.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.lg),
                            const _SectionTitle('Stempelkarten'),
                            const SizedBox(height: AppSpacing.md),
                            _StampPageView(
                              stamps: stamps,
                              onClaim: _showClaimDialog,
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClaimDialog(StampProgressModel card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Belohnung einlösen'),
        content: const Text(
          'Zeige diese Bestätigung dem Personal und markiere die Belohnung als erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _markClaimed(card);
            },
            child: const Text('Eingelöst'),
          ),
        ],
      ),
    );
  }

  Future<void> _markClaimed(StampProgressModel card) async {
    final uid = _service.authService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestoreService.updateDocument(
        FirebasePaths.userStampProgressEntry(uid, card.stampCardId),
        {
          'status': 'claimed',
          'claimedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }
}

class _QrSection extends StatelessWidget {
  const _QrSection({required this.card, required this.uid});

  final WalletCardModel card;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final qrData =
        'lokka://wallet/$uid/${card.merchantId}/${card.walletCode}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 240,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Halte diesen Code dem Scanner vor',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: AppColors.surfaceGray,
            borderRadius: BorderRadius.circular(100),
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () {
                Clipboard.setData(ClipboardData(text: card.walletCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code kopiert'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.walletCode,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Text(
      title,
      style: tt.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _StampPageView extends StatefulWidget {
  const _StampPageView({required this.stamps, required this.onClaim});

  final List<StampProgressModel> stamps;
  final void Function(StampProgressModel) onClaim;

  @override
  State<_StampPageView> createState() => _StampPageViewState();
}

class _StampPageViewState extends State<_StampPageView> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.95);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 330,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.stamps.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) {
              final s = widget.stamps[i];
              return Padding(
                padding: EdgeInsets.only(
                  right: i < widget.stamps.length - 1 ? 12 : 0,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: StampProgressCard(
                    progress: s,
                    onClaim: s.isCompleted && !s.isClaimed
                        ? () => widget.onClaim(s)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.stamps.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.stamps.length, (i) {
              final cs = Theme.of(context).colorScheme;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
