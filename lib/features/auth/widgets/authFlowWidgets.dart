import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';
import '../providers/authProvider.dart';

class AuthFlowScope extends StatelessWidget {
  const AuthFlowScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(
        authService: context.read<AuthService>(),
        firestoreService: context.read<FirestoreService>(),
        languageService: context.read<LanguageService>(),
      ),
      child: child,
    );
  }
}

/// Calm, centered auth shell – Chromium Experience / Material 3.
/// One tonal brand mark, display/headline title, soft outlined card.
/// The [dark] flag is kept for API compatibility; it now only nudges the
/// accent of the brand mark (merchant vs. user) within the same light system.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.children,
    this.dark = false,
    this.icon,
  });

  final String titleKey;
  final String subtitleKey;
  final List<Widget> children;

  /// Kept for compatibility. `true` marks the merchant flow.
  final bool dark;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Merchant-Flows (dark:true) rendern im Google-Home-Dark-Look:
    // dunkler Grund, helle Schrift, dunkle Karte mit Grün-Akzent.
    final scaffoldBg =
        dark ? MerchantPremiumColors.base : AppColors.surfaceBg;
    final cardBg = dark ? MerchantPremiumColors.surface : AppColors.surfaceBg;
    final cardBorder =
        dark ? MerchantPremiumColors.line : cs.outlineVariant;
    final titleColor =
        dark ? MerchantPremiumColors.ink : cs.onSurface;
    final subtitleColor =
        dark ? MerchantPremiumColors.muted : cs.onSurfaceVariant;
    final foreground =
        dark ? MerchantPremiumColors.ink : cs.onSurface;
    final markBg =
        dark ? MerchantPremiumColors.goldSoft : cs.secondaryContainer;
    final markFg =
        dark ? MerchantPremiumColors.gold : cs.onSecondaryContainer;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: foreground,
        elevation: 0,
        leading: IconButton(
          tooltip: texts.text('common.back'),
          color: foreground,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: markBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon ?? Icons.account_balance_wallet_rounded,
                      color: markFg,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    texts.text(titleKey),
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: -0.4,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    texts.text(subtitleKey),
                    style: tt.bodyLarge?.copyWith(
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.labelKey,
    this.keyboardType,
    this.obscureText = false,
    this.required = false,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String labelKey;
  final TextInputType? keyboardType;
  final bool obscureText;

  /// Hängt ein „ *" an das Label (Pflichtfeld-Markierung).
  final bool required;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Heller Look: gleiches Grau wie bisher; dunkler Merchant-Look: dunkles
    // Feld aus dem Theme, damit das Eingabefeld nicht auf der Karte „leuchtet".
    final fillColor =
        isDark ? theme.colorScheme.surfaceContainerHigh : AppColors.surfaceGray;
    final label = texts.text(labelKey) + (required ? ' *' : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        autofillHints: autofillHints,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Pflicht-Einwilligung mit antippbarem Rechts-Link (AGB / Datenschutz).
class AuthConsentCheck extends StatelessWidget {
  const AuthConsentCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.leading,
    required this.linkLabel,
    required this.onLinkTap,
    this.trailing = '',
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Text vor dem Link, z. B. „Ich akzeptiere die ".
  final String leading;
  final String linkLabel;
  final String trailing;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              behavior: HitTestBehavior.opaque,
              child: Text.rich(
                TextSpan(
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  children: [
                    TextSpan(text: leading),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: onLinkTap,
                        child: Text(
                          linkLabel,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    if (trailing.isNotEmpty) TextSpan(text: trailing),
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

class AuthCheck extends StatelessWidget {
  const AuthCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelKey,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final tt = Theme.of(context).textTheme;
    return CheckboxListTile(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (value) => onChanged(value ?? false),
      title: Text(texts.text(labelKey), style: tt.bodyMedium),
    );
  }
}

class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 20, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthWarningBox extends StatelessWidget {
  const AuthWarningBox({super.key, required this.messageKey});

  final String messageKey;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texts.text(messageKey),
              style: tt.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.labelKey,
    required this.onPressed,
  });

  final String labelKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final loading = context.select<AuthProvider, bool>((value) => value.isLoading);
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(texts.text(labelKey)),
    );
  }
}

bool validateEmail(String email) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
}

String? validateRequiredAuth({
  required LanguageService texts,
  required List<String> values,
  String? email,
  String? password,
  bool checksRequired = false,
  bool checksAccepted = true,
}) {
  if (values.any((value) => value.trim().isEmpty)) {
    return texts.text('auth.error.required');
  }
  if (email != null && !validateEmail(email)) {
    return texts.text('auth.error.email');
  }
  if (password != null && password.length < 6) {
    return texts.text('auth.error.password');
  }
  if (checksRequired && !checksAccepted) {
    return texts.text('auth.error.checks');
  }
  return null;
}
