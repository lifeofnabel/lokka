import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/merchantFeatureModule.dart';
import '../providers/merchantFeaturesProvider.dart';
import '../services/merchantFeaturesService.dart';

/// „Funktionen" – bewusst einfach gehalten: pro Funktion eine ruhige Karte
/// mit großem Namen, einem Satz Erklärung (was der Kunde sieht) und einem
/// Schalter. Inline-Deutsch statt i18n-Keys, damit die Texte hier klar und
/// alltagstauglich bleiben. Toggle-/Speicher-Logik ist unverändert.
class MerchantFeaturesPage extends StatelessWidget {
  const MerchantFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantFeaturesProvider(
        service: MerchantFeaturesService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantFeaturesView(),
    );
  }
}

class _MerchantFeaturesView extends StatelessWidget {
  const _MerchantFeaturesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeaturesProvider>();

    return MerchantToolScaffold(
      title: 'Funktionen',
      subtitle:
          'Schalte ein, was dein Laden anbietet – alles andere bleibt für Kunden unsichtbar.',
      child: provider.isLoading
          ? const MerchantLoadingCards(count: 5)
          : provider.error != null
              ? MerchantErrorState(
                  message: provider.error!,
                  onRetry: provider.load,
                )
              : const _FeatureControls(),
    );
  }
}

/// Anzeigename + Ein-Satz-Erklärung (Kundensicht) pro Funktion – bewusst
/// lokal überschrieben statt texts.text(...), damit die Sprache hier
/// einfach bleibt.
class _FeatureCopy {
  const _FeatureCopy(this.name, this.description);

  final String name;
  final String description;
}

const Map<String, _FeatureCopy> _featureCopy = {
  'feedPosts': _FeatureCopy(
    'Beiträge',
    'Deine Neuigkeiten und Angebote erscheinen bei deinen Kunden in der App.',
  ),
  'stampCards': _FeatureCopy(
    'Stempelkarten',
    'Kunden sammeln bei jedem Besuch einen Stempel und bekommen am Ende eine Belohnung.',
  ),
  'pointsSystems': _FeatureCopy(
    'Punkte sammeln',
    'Kunden sammeln beim Einkaufen Punkte und lösen sie später bei dir ein.',
  ),
  'menuCatalog': _FeatureCopy(
    'Speisekarte & Angebot',
    'Kunden sehen deine Karte mit Preisen direkt in der App.',
  ),
  'coupons': _FeatureCopy(
    'Gutscheine',
    'Kunden lösen Gutscheine von dir in der App ein.',
  ),
  'campaigns': _FeatureCopy(
    'Aktionen & Gewinnspiele',
    'Du startest kleine Aktionen, bei denen Kunden mitmachen.',
  ),
  'shiftPlanner': _FeatureCopy(
    'Schichtplan',
    'Du planst die Arbeitszeiten deines Teams.',
  ),
  'deliveryService': _FeatureCopy(
    'Lieferservice',
    'Kunden bestellen bei dir nach Hause.',
  ),
  'reservations': _FeatureCopy(
    'Tisch reservieren',
    'Kunden reservieren vorab einen Platz bei dir.',
  ),
};

const Map<String, _FeatureCopy> _optionCopy = {
  'catalogOrderQrCashier': _FeatureCopy(
    'Bestellen per QR-Code',
    'Kunden scannen einen Code bei dir im Laden und bestellen selbst.',
  ),
  'catalogOrderSendCashier': _FeatureCopy(
    'Bestellung an die Kasse',
    'Bestellungen deiner Kunden kommen direkt bei dir an der Kasse an.',
  ),
  'catalogTableOrders': _FeatureCopy(
    'Bestellen am Tisch',
    'Kunden bestellen direkt von ihrem Tisch aus.',
  ),
};

String _featureName(MerchantFeatureModule module) =>
    _featureCopy[module.key]?.name ?? module.key;

String _featureDescription(MerchantFeatureModule module) =>
    _featureCopy[module.key]?.description ?? '';

class _FeatureControls extends StatelessWidget {
  const _FeatureControls();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeaturesProvider>();
    final feed = merchantFeatureModuleByKey('feedPosts')!;
    final stamps = merchantFeatureModuleByKey('stampCards')!;
    final points = merchantFeatureModuleByKey('pointsSystems')!;
    final catalog = merchantFeatureModuleByKey('menuCatalog')!;
    final comingSoon =
        merchantFeatureModules.where((module) => module.comingSoon).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AlwaysOnFeatureCard(module: feed),
        const SizedBox(height: AppSpacing.md),
        _FeatureCard(module: stamps),
        const SizedBox(height: AppSpacing.md),
        _FeatureCard(module: points),
        const SizedBox(height: AppSpacing.md),
        _CatalogFeatureCard(module: catalog),
        const SizedBox(height: AppSpacing.lg),
        _ComingSoonCard(modules: comingSoon),
        const SizedBox(height: AppSpacing.lg),
        MerchantPrimaryButton(
          label: 'Speichern',
          isLoading: provider.isSaving,
          onPressed: provider.hasChanges ? () => _confirmSave(context) : null,
        ),
      ],
    );
  }
}

/// Beiträge sind Pflicht – Karte ohne Schalter, dafür mit „Immer aktiv".
class _AlwaysOnFeatureCard extends StatelessWidget {
  const _AlwaysOnFeatureCard({required this.module});

  final MerchantFeatureModule module;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: MerchantPremiumColors.gold.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FeatureIcon(icon: module.icon, active: true),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _featureName(module),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _StatusPill(label: 'Immer aktiv', active: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _featureDescription(module),
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Funktion = eine Karte: Icon, großer Name, ein Satz Erklärung,
/// Schalter und klarer Aktiv/Aus-Zustand.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.module});

  final MerchantFeatureModule module;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeaturesProvider>();
    final enabled = provider.isEnabled(module);

    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: enabled
          ? MerchantPremiumColors.gold.withValues(alpha: 0.30)
          : MerchantPremiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FeatureIcon(icon: module.icon, active: enabled),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _featureName(module),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: enabled,
                onChanged: (value) => provider.setEnabled(module, value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _featureDescription(module),
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _StatusPill(label: enabled ? 'Aktiv' : 'Aus', active: enabled),
        ],
      ),
    );
  }
}

/// Speisekarte mit Bestell-Optionen darunter (nur sichtbar, wenn die
/// Speisekarte eingeschaltet ist). Logik unverändert.
class _CatalogFeatureCard extends StatelessWidget {
  const _CatalogFeatureCard({required this.module});

  final MerchantFeatureModule module;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeaturesProvider>();
    final enabled = provider.isEnabled(module);
    final orderOptions =
        module.options.where((option) => option.key != 'catalogOnly').toList();

    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: enabled
          ? MerchantPremiumColors.gold.withValues(alpha: 0.30)
          : MerchantPremiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FeatureIcon(icon: module.icon, active: enabled),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _featureName(module),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: enabled,
                onChanged: (value) => provider.setEnabled(module, value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _featureDescription(module),
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _StatusPill(label: enabled ? 'Aktiv' : 'Aus', active: enabled),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: MerchantPremiumColors.line),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Wie können Kunden bestellen?',
              style: TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Schalte nur ein, was du wirklich anbietest – alles ist freiwillig.',
              style: TextStyle(
                color: MerchantPremiumColors.muted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...orderOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CatalogOptionRow(module: module, option: option),
              ),
            ),
            const _MenuSettingsButton(),
          ],
        ],
      ),
    );
  }
}

class _CatalogOptionRow extends StatelessWidget {
  const _CatalogOptionRow({required this.module, required this.option});

  final MerchantFeatureModule module;
  final MerchantFeatureOption option;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeaturesProvider>();
    final enabled = provider.optionEnabled(module, option);
    final copy = _optionCopy[option.key];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: enabled
              ? MerchantPremiumColors.gold.withValues(alpha: 0.35)
              : MerchantPremiumColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            option.icon,
            size: 22,
            color: enabled
                ? MerchantPremiumColors.gold
                : MerchantPremiumColors.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy?.name ?? option.key,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  copy?.description ?? '',
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: (value) =>
                provider.setOptionEnabled(module, option, value),
          ),
        ],
      ),
    );
  }
}

/// Verlinkt die Speisekarten-Einstellung (Kunden-Sicht der Karte).
class _MenuSettingsButton extends StatelessWidget {
  const _MenuSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MerchantPremiumColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: () => context.go('/merchant/menu'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: MerchantPremiumColors.line),
          ),
          child: Row(
            children: const [
              Icon(Icons.restaurant_menu_rounded,
                  color: MerchantPremiumColors.ink, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Speisekarte für Kunden einrichten',
                  style: TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: MerchantPremiumColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ruhige Übersicht der Funktionen, die bald kommen – ohne Schalter,
/// damit nichts verwirrt.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.modules});

  final List<MerchantFeatureModule> modules;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bald verfügbar',
            style: TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Daran arbeiten wir gerade – du musst nichts tun.',
            style: TextStyle(
              color: MerchantPremiumColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(module.icon,
                      size: 20, color: MerchantPremiumColors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _featureName(module),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.mutedLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _StatusPill(label: 'Bald', active: false),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Großer, klarer Zustand: grünes „Aktiv" oder neutrales „Aus".
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground =
        active ? MerchantPremiumColors.success : MerchantPremiumColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? MerchantPremiumColors.successSoft
            : MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? MerchantPremiumColors.success.withValues(alpha: 0.45)
              : MerchantPremiumColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: active
            ? MerchantPremiumColors.goldSoft
            : MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: active
              ? MerchantPremiumColors.gold.withValues(alpha: 0.30)
              : MerchantPremiumColors.line,
        ),
      ),
      child: Icon(
        icon,
        color: active
            ? MerchantPremiumColors.gold
            : MerchantPremiumColors.muted,
      ),
    );
  }
}

Future<void> _confirmSave(BuildContext context) async {
  final provider = context.read<MerchantFeaturesProvider>();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(14),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        radius: 32,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Änderungen speichern?',
                style: TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Deine Kunden sehen die Änderungen sofort in der App.',
                style: TextStyle(
                  color: MerchantPremiumColors.muted,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPremiumColors.gold,
                  foregroundColor: MerchantPremiumColors.goldSoft,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Ja, speichern'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (confirmed != true) return;
  await provider.saveChanges();
  if (!context.mounted) return;
  // Bei Fehler NICHT weiternavigieren (#22) – der Fehler bleibt auf der Seite
  // sichtbar (MerchantErrorState rendert provider.error).
  if (provider.error != null) return;
  context.go('/merchant/dashboard');
}
