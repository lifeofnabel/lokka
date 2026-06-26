import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../stamps/services/stampFunctionsService.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/responsiveContentWidth.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/gamification/widgets/celebration.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';
import 'package:lokka/features/user/wallet/widgets/stampProgressCard.dart';

class UserStampPage extends StatefulWidget {
  const UserStampPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  State<UserStampPage> createState() => _UserStampPageState();
}

class _UserStampPageState extends State<UserStampPage> {
  late final FirestoreService _firestoreService;
  late final AuthService _authService;
  late final PageController _pageCtrl;
  StreamSubscription<List<StampProgressModel>>? _sub;

  List<StampProgressModel> _cards = [];
  bool _isLoading = true;
  String? _error;
  int _page = 0;

  String? get _uid => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _authService = context.read<AuthService>();
    _pageCtrl = PageController(viewportFraction: 0.92);
    _subscribe();
  }

  void _subscribe() {
    final uid = _uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _cards = [];
      });
      return;
    }

    _sub = _firestoreService
        .collection(FirebasePaths.userStampProgress(uid))
        .where('merchantId', isEqualTo: widget.merchantId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StampProgressModel.fromMap(d.data())).toList())
        .listen(
          (list) {
            if (mounted) setState(() { _cards = list; _isLoading = false; });
          },
          onError: (e) {
            if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Stempelkarten',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveContentWidth(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingState();
    }
    if (_error != null) {
      return const AppErrorState(message: 'Laden fehlgeschlagen');
    }
    if (_cards.isEmpty) {
      return const AppEmptyState(
        icon: Icons.loyalty_rounded,
        title: 'Keine Stempelkarten',
        message: 'Sammle Stempel beim nächsten Besuch.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: StampProgressCard(
                progress: _cards[i],
                onClaim: _cards[i].isCompleted && !_cards[i].isClaimed
                    ? () => _showClaimDialog(_cards[i])
                    : null,
              ),
            ),
          ),
        ),
        if (_cards.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_cards.length, (i) {
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
          ),
        const SizedBox(height: AppSpacing.md),
      ],
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
    final uid = _uid;
    if (uid == null) return;
    final cache = context.read<LocalCacheService>();
    try {
      // Server-authored: converting a full card into an earned reward is done by
      // the claimReward Cloud Function (clients can no longer write stampProgress).
      await StampFunctionsService().claimReward(
        merchantId: card.merchantId,
        cardId: card.stampCardId,
      );
      if (mounted) {
        await Celebration.maybeShow(
          context,
          cache,
          title: 'Belohnung gesichert! 🎉',
          subtitle: 'Zeig sie an der Kasse vor.',
        );
      }
    } catch (_) {}
  }
}
