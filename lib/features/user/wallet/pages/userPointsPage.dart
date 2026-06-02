import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.merchantName,
          style: const TextStyle(
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
            Text('Laden fehlgeschlagen',
                style: TextStyle(color: AppColors.gray500, fontSize: 16)),
          ],
        ),
      );
    }
    if (_progress == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_outlined, size: 64, color: AppColors.gray300),
            SizedBox(height: AppSpacing.md),
            Text(
              'Noch keine Punkte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.gray500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sammle Punkte bei deinem nächsten Einkauf.',
              style: TextStyle(fontSize: 14, color: AppColors.gray300),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          PointsProgressCard(
            progress: _progress!,
            merchantName: widget.merchantName,
          ),
          const SizedBox(height: AppSpacing.md),
          _PointsInfoCard(progress: _progress!),
        ],
      ),
    );
  }
}

class _PointsInfoCard extends StatelessWidget {
  const _PointsInfoCard({required this.progress});

  final PointsProgressModel progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Row('Aktuelle Punkte', '${progress.currentPoints}'),
          const Divider(height: 20, color: AppColors.border),
          _Row('Gesamtpunkte', '${progress.lifetimePoints}'),
          if (progress.resetDay != null) ...[
            const Divider(height: 20, color: AppColors.border),
            _Row('Reset-Tag', '${progress.resetDay}. des Monats'),
          ],
          if (progress.status.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.border),
            _Row('Status', progress.status),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.gray500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}
