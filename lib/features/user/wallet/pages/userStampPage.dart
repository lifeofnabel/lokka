import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';
import 'package:lokka/features/user/wallet/widgets/stampProgressCard.dart';

const _users = 'users';
const _stampProgress = 'stampProgress';

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
        .collection('$_users/$uid/$_stampProgress')
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Stempelkarten',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.gray300),
            SizedBox(height: AppSpacing.md),
            Text(
              'Laden fehlgeschlagen',
              style: TextStyle(color: AppColors.gray500, fontSize: 16),
            ),
          ],
        ),
      );
    }
    if (_cards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stamp, size: 64, color: AppColors.gray300),
            SizedBox(height: AppSpacing.md),
            Text(
              'Keine Stempelkarten',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.gray500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sammle Stempel beim nächsten Besuch.',
              style: TextStyle(fontSize: 14, color: AppColors.gray300),
            ),
          ],
        ),
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
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? AppColors.mintStrong
                        : AppColors.gray300,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text(
          'Belohnung einlösen',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Zeige diese Bestätigung dem Personal und markiere die Belohnung als erhalten.',
          style: TextStyle(color: AppColors.gray700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mintStrong,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
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
    try {
      await _firestoreService.updateDocument(
        '$_users/$uid/$_stampProgress/${card.stampCardId}',
        {
          'status': 'claimed',
          'claimedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }
}
