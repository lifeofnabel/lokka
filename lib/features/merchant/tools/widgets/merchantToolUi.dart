import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';

class MerchantToolScaffold extends StatelessWidget {
  const MerchantToolScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.backPath,
    this.showHeader = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final String? backPath;

  /// Wenn false, rendert die Seite ihren eigenen Topper im Body und der
  /// große Header-Block hier wird weggelassen (vermeidet doppelte Titel).
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MerchantPremiumColors.base,
      appBar: AppBar(
        backgroundColor: MerchantPremiumColors.base,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop() || backPath != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else if (backPath != null) {
                    context.go(backPath!);
                  }
                },
              )
            : null,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: trailing!,
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MerchantPremiumColors.base,
              MerchantPremiumColors.baseElevated,
              MerchantPremiumColors.base,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  if (showHeader) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: MerchantPremiumColors.surface,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.02,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MerchantPremiumColors.mutedLight,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MerchantInfoTooltip extends StatelessWidget {
  const MerchantInfoTooltip({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          color: MerchantPremiumColors.ink,
          size: 18,
        ),
      ),
    );
  }
}

class MerchantEmptyState extends StatelessWidget {
  const MerchantEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const MerchantPremiumIconBox(
            icon: Icons.add_business_rounded,
            size: 52,
            iconSize: 24,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _visibleError(texts, message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class MerchantErrorState extends StatelessWidget {
  const MerchantErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const MerchantPremiumIconBox(
            icon: Icons.error_outline_rounded,
            size: 52,
            iconSize: 24,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            texts.text('common.errorTitle'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _visibleError(texts, message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: Text(texts.text('common.retry'))),
        ],
      ),
    );
  }
}

String _visibleError(LanguageService texts, String message) {
  final cleaned = message
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
  return texts.text(cleaned);
}

class MerchantLoadingCards extends StatelessWidget {
  const MerchantLoadingCards({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Container(
          height: index == 0 ? 96 : 82,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: MerchantPremiumColors.surface.withValues(alpha: index == 0 ? 0.96 : 0.88),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: MerchantPremiumColors.line),
          ),
        ),
      ),
    );
  }
}

class MerchantTextField extends StatelessWidget {
  const MerchantTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        color: MerchantPremiumColors.ink,
        fontWeight: FontWeight.w800,
      ),
      decoration: merchantPremiumInputDecoration(label: label, hint: hint),
    );
  }
}

class MerchantPrimaryButton extends StatelessWidget {
  const MerchantPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon ?? Icons.check_rounded),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: MerchantPremiumColors.coral,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
