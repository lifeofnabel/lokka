import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

class MeinePartnerPage extends StatefulWidget {
  const MeinePartnerPage({super.key});

  @override
  State<MeinePartnerPage> createState() => _MeinePartnerPageState();
}

class _MeinePartnerPageState extends State<MeinePartnerPage> {
  late final FirestoreService _firestoreService;
  late final AuthService _authService;

  List<WalletCardModel> _cards = [];
  bool _loading = true;
  String? _error;

  /// Merchants unfollowed in THIS session — their row stays (showing „Folgen")
  /// until the page is reloaded, Instagram-style.
  Set<String> _unfollowed = {};
  Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _authService = context.read<AuthService>();
    _load();
  }

  Future<void> _load() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final snap = await _firestoreService
          .collection(FirebasePaths.userWalletCards(uid))
          .get();
      final cards = snap.docs
          .map((d) => WalletCardModel.fromMap(d.data()))
          .where((c) => c.merchantId.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _cards = cards;
          _unfollowed = {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Instagram-style follow toggle. Unfollow really deletes the user-owned
  /// walletCards doc (source of truth → also removes it from the Wallet), but the
  /// row stays in this list showing „Folgen" until reload. Re-follow recreates
  /// the doc from the card we still hold in memory. Stamp progress / earned
  /// rewards are server-only, so they survive both ways.
  Future<void> _toggleFollow(WalletCardModel card) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final mid = card.merchantId;
    if (_busy.contains(mid)) return;
    final wasUnfollowed = _unfollowed.contains(mid);
    setState(() => _busy = {..._busy, mid});
    try {
      if (wasUnfollowed) {
        await _firestoreService.setDocument(
            FirebasePaths.userWalletCard(uid, mid), _cardData(card),
            merge: true);
        await _setFollowerFlag(mid, uid, true);
        if (mounted) setState(() => _unfollowed = {..._unfollowed}..remove(mid));
      } else {
        await _firestoreService
            .document(FirebasePaths.userWalletCard(uid, mid))
            .delete();
        await _setFollowerFlag(mid, uid, false);
        if (mounted) setState(() => _unfollowed = {..._unfollowed, mid});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aktion fehlgeschlagen. Bitte erneut versuchen.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = {..._busy}..remove(mid));
    }
  }

  Future<void> _setFollowerFlag(String mid, String uid, bool value) async {
    try {
      await _firestoreService.setDocument(
        FirebasePaths.merchantCustomer(mid, uid),
        {'uid': uid, 'isFollower': value},
        merge: true,
      );
    } catch (_) {
      // Best-effort only — the walletCards write is the source of truth.
    }
  }

  Map<String, dynamic> _cardData(WalletCardModel card) => {
        'merchantId': card.merchantId,
        'merchantName': card.merchantName,
        'merchantLogoUrl': card.merchantLogoUrl,
        'merchantCoverUrl': card.merchantCoverUrl,
        'merchantCity': card.merchantCity,
        'merchantShopType': card.merchantShopType,
        'merchantOrigin': card.merchantOrigin,
        'walletCode': card.walletCode,
        'walletNumber': card.walletNumber,
        'prefix': card.prefix,
        'status': 'active',
        'hasStampCards': card.hasStampCards,
        'hasPoints': card.hasPoints,
        'hasCoupons': card.hasCoupons,
        'addedStampCardIds': card.addedStampCardIds,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
      };

  Future<void> _openPartner(BuildContext context, String merchantId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final doc = await _firestoreService
          .document(FirebasePaths.publicMerchant(merchantId))
          .get();
      if (!context.mounted) return;
      Navigator.pop(context);
      if (doc.exists && doc.data() != null) {
        final merchant = PublicMerchantUserModel.fromMap(
            {...doc.data()!, 'merchantId': doc.id});
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => UserPartnerDetailPage(merchant: merchant)),
        );
      }
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Meine Partner'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_cards.isEmpty) {
      return const AppEmptyState(
        icon: Icons.store_outlined,
        title: 'Noch keine Partner',
        message: 'Scanne einen QR-Code oder besuche einen Partner.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, i) => _PartnerTile(
        card: _cards[i],
        onTap: () => _openPartner(ctx, _cards[i].merchantId),
        unfollowed: _unfollowed.contains(_cards[i].merchantId),
        busy: _busy.contains(_cards[i].merchantId),
        onToggle: () => _toggleFollow(_cards[i]),
      ),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  const _PartnerTile({
    required this.card,
    required this.onTap,
    required this.unfollowed,
    required this.busy,
    required this.onToggle,
  });

  final WalletCardModel card;
  final VoidCallback onTap;
  final bool unfollowed;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                clipBehavior: Clip.antiAlias,
                child: card.merchantLogoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: card.merchantLogoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Icon(
                          Icons.store_rounded,
                          size: 22,
                          color: cs.onSecondaryContainer,
                        ),
                      )
                    : Icon(Icons.store_rounded,
                        size: 22, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.merchantName,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (card.merchantCity.isNotEmpty)
                      Text(
                        card.merchantCity,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FollowButton(
                unfollowed: unfollowed,
                busy: busy,
                onToggle: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Instagram-style toggle: „Entfolgen" (outlined, currently following) ↔
/// „Folgen" (filled, after you unfollowed — until reload).
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.unfollowed,
    required this.busy,
    required this.onToggle,
  });

  final bool unfollowed;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (busy) {
      return const SizedBox(
        width: 96,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (unfollowed) {
      return FilledButton(
        onPressed: onToggle,
        // Override the app theme's full-width default (Size.fromHeight(52) =>
        // infinite width), which crashes inside a Row.
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: const Text('Folgen'),
      );
    }
    return OutlinedButton(
      onPressed: onToggle,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: cs.onSurfaceVariant,
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: const Text('Entfolgen'),
    );
  }
}
