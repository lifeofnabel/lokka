import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../providers/merchantMenuSettingsProvider.dart';
import '../services/merchantMenuSettingsService.dart';

/// „Speisekarte" – Merchant steuert, ob/wie Kunden seine Karte auf der
/// Partner-Seite sehen: externer Link und integrierte Lokka-Karte.
/// Die Gestaltung der Kundenansicht (Vorlage, Farbe, Theme, Spalten) liegt
/// jetzt auf der Katalog-Seite (`MerchantMenuDesignPage`).
/// Reine UI – State/Firestore liegen in Provider/Service (#42).
class MerchantMenuSettingsPage extends StatelessWidget {
  const MerchantMenuSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantMenuSettingsProvider(
        service: MerchantMenuSettingsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MenuSettingsView(),
    );
  }
}

class _MenuSettingsView extends StatefulWidget {
  const _MenuSettingsView();

  @override
  State<_MenuSettingsView> createState() => _MenuSettingsViewState();
}

class _MenuSettingsViewState extends State<_MenuSettingsView> {
  final _urlController = TextEditingController();
  MerchantMenuSettingsProvider? _provider;
  bool _syncedUrl = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<MerchantMenuSettingsProvider>()..addListener(_syncUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncUrl());
  }

  // URL-Feld einmalig aus dem geladenen Provider-Stand befüllen – nicht in build().
  void _syncUrl() {
    final provider = _provider;
    if (!mounted || provider == null || provider.isLoading || _syncedUrl) return;
    _urlController.text = provider.externalUrl;
    _syncedUrl = true;
  }

  @override
  void dispose() {
    _provider?.removeListener(_syncUrl);
    _urlController.dispose();
    super.dispose();
  }

  /// Dritte Speisekarten-Quelle neben getipptem Link/Lokka-Karte: PDF
  /// hochladen. Die Download-URL landet im selben URL-Feld wie ein
  /// getippter Link – für die Anzeige/Öffnen-Logik ist das identisch.
  Future<void> _uploadPdf() async {
    final texts = context.read<LanguageService>();
    final provider = context.read<MerchantMenuSettingsProvider>();
    final url = await provider.uploadMenuPdf();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (url != null) {
      _urlController.text = url;
      if (!provider.externalEnabled) provider.setExternalEnabled(true);
      messenger.showSnackBar(
        SnackBar(content: Text(texts.text('merchant.menu.pdfUploaded'))),
      );
    } else if (provider.pdfError != null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.pdfError!)));
    }
  }

  Future<void> _save() async {
    final texts = context.read<LanguageService>();
    final provider = context.read<MerchantMenuSettingsProvider>();
    final result = await provider.save(url: _urlController.text);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final key = switch (result) {
      MenuSaveResult.success => 'merchant.menu.saved',
      MenuSaveResult.missingUrl => 'merchant.menu.error.url',
      MenuSaveResult.error => 'merchant.menu.error.save',
    };
    messenger.showSnackBar(SnackBar(content: Text(texts.text(key))));
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantMenuSettingsProvider>();
    return MerchantToolScaffold(
      title: texts.text('merchant.menu.title'),
      subtitle: texts.text('merchant.menu.subtitle'),
      backPath: '/merchant/features',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.menu.tooltip')),
      child: provider.isLoading
          ? const MerchantLoadingCards(count: 3)
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : _form(context, texts, provider),
    );
  }

  Widget _form(
    BuildContext context,
    LanguageService texts,
    MerchantMenuSettingsProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Integrierte Lokka-Karte – EMPFOHLEN, erste Option, immer vorab
        // aktiviert (siehe MerchantMenuSettingsService.load: neu/nie
        // konfiguriert → integratedEnabled defaultet auf true).
        MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderColor: MerchantPremiumColors.gold.withValues(alpha: 0.30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SwitchRow(
                      icon: Icons.restaurant_menu_rounded,
                      title: texts.text('merchant.menu.integratedTitle'),
                      subtitle: texts.text('merchant.menu.integratedSubtitle'),
                      value: provider.integratedEnabled,
                      onChanged: provider.setIntegratedEnabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _RecommendedBadge(label: texts.text('merchant.menu.recommended')),
              if (provider.integratedEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: MerchantPremiumColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        texts.text('merchant.menu.integratedHint'),
                        style: const TextStyle(
                          color: MerchantPremiumColors.muted,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () => context.go('/merchant/catalog'),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(texts.text('merchant.menu.openCatalog')),
                        style: TextButton.styleFrom(
                          foregroundColor: MerchantPremiumColors.ink,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Externer Link ODER PDF-Upload (beide füllen dieselbe URL).
        MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SwitchRow(
                icon: Icons.link_rounded,
                title: texts.text('merchant.menu.externalTitle'),
                subtitle: texts.text('merchant.menu.externalSubtitle'),
                value: provider.externalEnabled,
                onChanged: provider.setExternalEnabled,
              ),
              if (provider.externalEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: texts.text('merchant.menu.urlHint'),
                    filled: true,
                    fillColor: MerchantPremiumColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.public_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Alternative zum Eintippen: PDF direkt hochladen – landet in
                // derselben URL (identisches „Öffnen"-Verhalten für Kunden).
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        texts.text('common.or'),
                        style: const TextStyle(
                          color: MerchantPremiumColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: provider.isUploadingPdf ? null : _uploadPdf,
                  icon: provider.isUploadingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(texts.text('merchant.menu.uploadPdf')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MerchantPremiumColors.ink,
                    side: const BorderSide(color: MerchantPremiumColors.line),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MerchantPrimaryButton(
          label: texts.text('merchant.menu.save'),
          icon: Icons.save_rounded,
          isLoading: provider.isSaving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          texts.text('merchant.menu.tip'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

/// Kleines Badge, das die Lokka-Karte als empfohlene erste Option markiert.
class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 58),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.gold,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: MerchantPremiumColors.goldSoft,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: MerchantPremiumColors.ink),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
