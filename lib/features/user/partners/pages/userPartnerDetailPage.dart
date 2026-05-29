import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/partners/widgets/partnerHeroCard.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

class UserPartnerDetailPage extends StatefulWidget {
  const UserPartnerDetailPage({super.key, required this.merchant});

  final PublicMerchantUserModel merchant;

  @override
  State<UserPartnerDetailPage> createState() => _UserPartnerDetailPageState();
}

class _UserPartnerDetailPageState extends State<UserPartnerDetailPage> {
  late final UserWalletService _walletService;
  bool _isInWallet = false;
  bool _isCheckingWallet = true;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _walletService = UserWalletService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
    );
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    final inWallet = await _walletService.isInWallet(widget.merchant.merchantId);
    if (mounted) {
      setState(() {
        _isInWallet = inWallet;
        _isCheckingWallet = false;
      });
    }
  }

  Future<void> _addToWallet() async {
    if (_isAdding || _isInWallet) return;
    setState(() => _isAdding = true);
    try {
      await _walletService.addToWallet(widget.merchant);
      if (mounted) {
        setState(() {
          _isInWallet = true;
          _isAdding = false;
        });
        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        _showError();
      }
    }
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.merchant.shopName} zur Wallet hinzugefügt'),
        backgroundColor: AppColors.mintStrong,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    );
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fehler beim Hinzufügen. Bitte versuche es erneut.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.merchant;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PartnerHeroCard(merchant: m),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.address.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: m.address,
                    ),
                  ],
                  if (m.phone.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      text: m.phone,
                    ),
                  ],
                  if (m.openingHours != null && m.openingHours!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _OpeningHoursRow(hours: m.openingHours!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _WalletButton(
                    isInWallet: _isInWallet,
                    isChecking: _isCheckingWallet,
                    isAdding: _isAdding,
                    onAdd: _addToWallet,
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.gray500),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.gray700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _OpeningHoursRow extends StatelessWidget {
  const _OpeningHoursRow({required this.hours});

  final Map<String, dynamic> hours;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.access_time_outlined, size: 18, color: AppColors.gray500),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: hours.entries.map((e) {
              return Text(
                '${e.key}: ${e.value}',
                style: const TextStyle(fontSize: 13, color: AppColors.gray700),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _WalletButton extends StatelessWidget {
  const _WalletButton({
    required this.isInWallet,
    required this.isChecking,
    required this.isAdding,
    required this.onAdd,
  });

  final bool isInWallet;
  final bool isChecking;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (isChecking) {
      return const SizedBox(
        height: 54,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (isInWallet) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.mintSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.mintStrong, size: 20),
            SizedBox(width: 8),
            Text(
              'In deiner Wallet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.mintStrong,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        onPressed: isAdding ? null : onAdd,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: isAdding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wallet_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Zur Wallet hinzufügen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
