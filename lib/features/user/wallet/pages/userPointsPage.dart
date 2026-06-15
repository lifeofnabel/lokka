import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/wallet/models/pointsProgressModel.dart';
import 'package:lokka/features/user/wallet/widgets/pointsProgressCard.dart';
import 'package:provider/provider.dart';

class UserPointsPage extends StatefulWidget {
  const UserPointsPage({
    super.key,
    required this.merchantId,
    required this.merchantName,
  });

  final String merchantId;
  final String merchantName;

  @override
  State<UserPointsPage> createState() => _UserPointsPageState();
}

class _UserPointsPageState extends State<UserPointsPage> {
  late final FirestoreService _firestoreService;
  late final AuthService _authService;
  StreamSubscription<PointsProgressModel?>? _sub;

  PointsProgressModel? _progress;
  bool _isLoading = true;
  String? _error;

  String? get _uid => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _authService = context.read<AuthService>();
    _subscribe();
  }

  void _subscribe() {
    final uid = _uid;
    if (uid == null) {
      setState(() { _isLoading = false; });
      return;
    }

    _sub = _firestoreService
        .document(FirebasePaths.userPointsProgressEntry(
          uid,
          widget.merchantId,
        ))
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? PointsProgressModel.fromMap(doc.data()!)
            : null)
        .listen(
          (p) {
            if (mounted) setState(() { _progress = p; _isLoading = false; });
          },
          onError: (e) {
            if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
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
          widget.merchantName,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingState();
    }
    if (_error != null) {
      return const AppErrorState(message: 'Laden fehlgeschlagen');
    }
    if (_progress == null) {
      return const AppEmptyState(
        icon: Icons.stars_outlined,
        title: 'Noch keine Punkte',
        message: 'Sammle Punkte bei deinem nächsten Einkauf.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: PointsProgressCard(
        progress: _progress!,
        merchantName: widget.merchantName,
      ),
    );
  }
}
