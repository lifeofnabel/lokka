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

/// „Funktionen verwalten" – bewusst einfach gehalten: pro Funktion eine ruhige
/// Karte mit großem Namen, einem Satz Erklärung (was der Kunde sieht) und einem
/// Schalter. Inline-Deutsch statt i18n-Keys ist hier die bewusste Entscheidung
/// (#59): die Copy ist alltagstauglicher als die knappen merchant.features.*-
/// Keys; die früheren ungenutzten titleKey/tooltipKey/releaseKey im Modell
/// wurden entfernt, damit es keine Doppelpflege/Toten Ballast mehr gibt.
/// Toggle-/Speicher-Logik ist unverändert.
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
      // Begriff identisch zur Einstiegskachel im Shop-Bereich („Funktionen
      // verwalten") – kein Vokabular-Bruch zwischen Einstieg und Ziel (#59).
      title: 'Funktionen verwalten',
      subtitle:
          'Schalte ein, was dein Laden anbietet – alles andere bleibt für Kunden unsichtbar.',
      // MerchantLoadingCards/MerchantErrorState sind die Standard-States des
      // dunklen MerchantPremium-Themes (durchgängig in allen Merchant-Seiten);
      // AppLoadingState/AppErrorState gehören zum hellen User-Bereich (#59).
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
  'catalogModeRunner': _FeatureCopy(
    'Runner-Modus',
    'Nur dein Personal (Runner) nimmt Bestellungen am Tisch auf und sendet sie an „Bestellungen". Runner legst du auf der Speisekarte-Seite an (Name + PIN). Schaltet die anderen Modi aus.',
  ),
  'catalogModeTable': _FeatureCopy(
    'Bestellen am Tisch',
    'Kunden scannen den QR an ihrem Tisch, bestellen selbst und senden direkt an „Bestellungen". Die Tisch-QR-Codes findest du auf der Speisekarte-Seite.',
  ),
  'catalogModeCashier': _FeatureCopy(
    'Bestellen & an Kasse zeigen',
    'Kunden stellen ihre Bestellung zusammen und bekommen einen QR-Code. Die Bestellung erscheint erst unter „Bestellungen", wenn dein Personal den Code an der Kasse bestätigt.',
  ),
  'catalogModeMenuOnly': _FeatureCopy(
    'Nur Speisekarte',
    'Reine Ansicht: Kunden sehen deine Karte (mit Übersetzung & Bildern), können aber nicht bestellen. Teilbarer QR-Code auf der Speisekarte-Seite. Schaltet die anderen Modi aus.',
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
    // Struktur ist statisch – hier KEIN watch (#59): so rebuildet ein Toggle
    // nur die betroffene Karte (jede Karte/Option watcht selektiv) und der
    // Save-Button (eigener Selector), nicht der gesamte Funktionen-Baum.
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
        const _SaveButton(),
      ],
    );
  }
}

/// Save-Button rebuildet nur bei Änderung von hasChanges/isSaving (#59) –
/// Selector statt context.watch des ganzen Providers.
class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return Selector<MerchantFeaturesProvider, (bool, bool)>(
      selector: (_, provider) => (provider.hasChanges, provider.isSaving),
      builder: (context, state, _) {
        final (hasChanges, isSaving) = state;
        return MerchantPrimaryButton(
          label: 'Speichern',
          isLoading: isSaving,
          onPressed: hasChanges ? () => _confirmSave(context) : null,
        );
      },
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
    // Nur auf den Enabled-Zustand DIESES Moduls hören (#59) – nicht den ganzen
    // Provider, sonst rebuildet jede Karte bei jedem fremden Toggle.
    final enabled = context.select<MerchantFeaturesProvider, bool>(
      (provider) => provider.isEnabled(module),
    );

    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: enabled
          ? MerchantPremiumColors.gold.withValues(alpha: 0.30)
          : MerchantPremiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
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
                Semantics(
                  label: _featureName(module),
                  child: Switch(
                    value: enabled,
                    onChanged: (value) => context
                        .read<MerchantFeaturesProvider>()
                        .setEnabled(module, value),
                  ),
                ),
              ],
            ),
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
    // Karte hört nur auf den Enabled-Zustand der Speisekarte (#59); die
    // Modus-Schalter watchen einzeln in _CatalogOptionRow.
    final enabled = context.select<MerchantFeaturesProvider, bool>(
      (provider) => provider.isEnabled(module),
    );
    // Nur die 4 Modi (Vor Ort/Mitnehmen + Abholzeit sind immer im Warenkorb).
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
          MergeSemantics(
            child: Row(
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
                Semantics(
                  label: _featureName(module),
                  child: Switch(
                    value: enabled,
                    onChanged: (value) => context
                        .read<MerchantFeaturesProvider>()
                        .setEnabled(module, value),
                  ),
                ),
              ],
            ),
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
            const Divider(
              height: 1,
              thickness: 1,
              color: MerchantPremiumColors.line,
            ),
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
    // Nur auf diesen Modus hören (#59) – nicht den ganzen Provider.
    final enabled = context.select<MerchantFeaturesProvider, bool>(
      (provider) => provider.optionEnabled(module, option),
    );
    final copy = _optionCopy[option.key];
    final name = copy?.name ?? option.key;

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
      child: MergeSemantics(
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
              child: Text(
                name,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if ((copy?.description ?? '').isNotEmpty)
              Tooltip(
                message: copy!.description,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 8),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                // 44px Tap-Target für das Info-Icon (#59 – Touch-Target).
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.info_outline_rounded,
                      size: 18, color: MerchantPremiumColors.muted),
                ),
              ),
            const SizedBox(width: 8),
            Semantics(
              label: name,
              child: Switch(
                value: enabled,
                onChanged: (value) => context
                    .read<MerchantFeaturesProvider>()
                    .setOptionEnabled(module, option, value),
              ),
            ),
          ],
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
              // Mindestens 13px für Lesbarkeit (#59 – keine Mini-Texte <13px).
              fontSize: 13,
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

// Dunkle On-Color für Text/Icon auf dem grünen „gold"-Akzent – sattes Dunkel
// statt goldSoft (das auf gold zu kontrastarm war, #59). Kontrast deutlich
// >=4.5:1.
const Color _onGold = Color(0xFF13261F);

Future<void> _confirmSave(BuildContext context) async {
  final provider = context.read<MerchantFeaturesProvider>();
  // Geteilte BottomSheet-Hülle (dunkler Grund, Drag-Handle, SafeArea) mit
  // isScrollControlled, damit das Sheet bei großer Schrift nicht überläuft (#59).
  final confirmed = await showMerchantBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            foregroundColor: _onGold,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: const Text('Ja, speichern'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MerchantSecondaryButton(
          label: 'Abbrechen',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
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
