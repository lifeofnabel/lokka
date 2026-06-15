import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/menuDesign.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../providers/merchantMenuSettingsProvider.dart';
import '../services/merchantMenuSettingsService.dart';

/// „Speisekarte" – Merchant steuert, ob/wie Kunden seine Karte auf der
/// Partner-Seite sehen: externer Link, integrierte Lokka-Karte und die
/// Gestaltung der Kundenansicht (Vorlage, Farbe, Theme, Spalten).
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
        // Externer Link
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
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Integrierte Lokka-Karte
        MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SwitchRow(
                icon: Icons.restaurant_menu_rounded,
                title: texts.text('merchant.menu.integratedTitle'),
                subtitle: texts.text('merchant.menu.integratedSubtitle'),
                value: provider.integratedEnabled,
                onChanged: provider.setIntegratedEnabled,
              ),
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
        // Gestaltung der Kundenkarte (Vorlage + Farbe + Theme + Spalten)
        _DesignCard(provider: provider),
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

/// Karte „Aussehen der Kundenkarte": Vorlagen-Auswahl mit Live-Mini-Vorschau,
/// Akzentfarbe, Hell/Dunkel und Artikel-pro-Reihe.
class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.provider});

  final MerchantMenuSettingsProvider provider;

  @override
  Widget build(BuildContext context) {
    final style = provider.style;
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.goldSoft,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.palette_rounded,
                    color: MerchantPremiumColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aussehen der Kundenkarte',
                      style: TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Wähle, wie Kunden deine Speisekarte sehen.',
                      style: TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 2×2 Vorlagen mit Live-Mini-Vorschau.
          const _SectionLabel('Vorlage'),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.86,
            children: [
              for (final layout in MenuLayoutStyle.values)
                _LayoutChoiceTile(
                  layout: layout,
                  style: style,
                  selected: style.layout == layout,
                  onTap: () => provider.setLayout(layout),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Akzentfarbe.
          const _SectionLabel('Akzentfarbe'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in MenuDesign.palette)
                _AccentSwatch(
                  color: Color(color),
                  selected: style.accentColor == color,
                  onTap: () => provider.setAccentColor(color),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Hell / Dunkel.
          const _SectionLabel('Modus'),
          const SizedBox(height: AppSpacing.sm),
          _SegmentedControl(
            accent: style.accent,
            selectedIndex: style.darkMode ? 1 : 0,
            onChanged: (i) => provider.setDarkMode(i == 1),
            items: const [
              _SegItem(icon: Icons.light_mode_rounded, label: 'Hell'),
              _SegItem(icon: Icons.dark_mode_rounded, label: 'Dunkel'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Artikel pro Reihe.
          const _SectionLabel('Artikel pro Reihe'),
          const SizedBox(height: AppSpacing.sm),
          _SegmentedControl(
            accent: style.accent,
            selectedIndex: style.safeColumns == 2 ? 1 : 0,
            onChanged: (i) => provider.setColumns(i == 1 ? 2 : 1),
            items: const [
              _SegItem(icon: Icons.crop_portrait_rounded, label: '1 pro Reihe'),
              _SegItem(icon: Icons.grid_view_rounded, label: '2 pro Reihe'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: MerchantPremiumColors.muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// Ein anklickbares Vorlagen-Kästchen mit Live-Mini-Vorschau und Label.
class _LayoutChoiceTile extends StatelessWidget {
  const _LayoutChoiceTile({
    required this.layout,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final MenuLayoutStyle layout;
  final MenuDesign style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = style.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : MerchantPremiumColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _MiniMenuPreview(layout: layout, style: style)),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    layout.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? accent : MerchantPremiumColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 17,
                  color: selected ? accent : MerchantPremiumColors.muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal-Repräsentation einer Vorlage – spiegelt Akzentfarbe, Hell/Dunkel
/// und Artikel-pro-Reihe der aktuellen Auswahl wider.
class _MiniMenuPreview extends StatelessWidget {
  const _MiniMenuPreview({required this.layout, required this.style});

  final MenuLayoutStyle layout;
  final MenuDesign style;

  @override
  Widget build(BuildContext context) {
    final dark = style.darkMode;
    final bg = dark ? const Color(0xFF15171B) : const Color(0xFFF3F4F1);
    final card = dark ? const Color(0xFF262A30) : Colors.white;
    final line = dark ? const Color(0xFF3B4047) : const Color(0xFFE3E6E0);
    final accent = style.accent;
    final cols = style.safeColumns;

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? Colors.white12 : Colors.black12),
      ),
      child: _content(card, line, accent, cols),
    );
  }

  Widget _content(Color card, Color line, Color accent, int cols) {
    switch (layout) {
      case MenuLayoutStyle.magazine:
        return _rows(rows: 1, cols: cols, build: () => _heroMini(accent));
      case MenuLayoutStyle.gallery:
        return _rows(
          rows: cols == 2 ? 2 : 2,
          cols: cols,
          build: () => _galleryMini(card, line, accent),
        );
      case MenuLayoutStyle.compact:
        return _rows(
          rows: cols == 2 ? 3 : 4,
          cols: cols,
          build: () => _compactMini(line, accent),
        );
      case MenuLayoutStyle.list:
        return _rows(
          rows: cols == 2 ? 2 : 3,
          cols: cols,
          build: () => cols == 2
              ? _galleryMini(card, line, accent)
              : _listRowMini(card, line, accent),
        );
    }
  }

  // Ordnet [rows] Zeilen gleichmäßig an; bei 2 Spalten je zwei Elemente/Zeile.
  Widget _rows({
    required int rows,
    required int cols,
    required Widget Function() build,
  }) {
    final children = <Widget>[];
    for (var r = 0; r < rows; r++) {
      final line = cols == 2
          ? Row(
              children: [
                Expanded(child: build()),
                const SizedBox(width: 6),
                Expanded(child: build()),
              ],
            )
          : build();
      children.add(Expanded(child: line));
      if (r < rows - 1) children.add(const SizedBox(height: 6));
    }
    return Column(children: children);
  }

  Widget _bar(Color color, {double widthFactor = 1, double height = 4}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _listRowMini(Color card, Color line, Color accent) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _bar(line, widthFactor: 0.8),
                const SizedBox(height: 3),
                _bar(line, widthFactor: 0.5),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 12,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryMini(Color card, Color line, Color accent) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _bar(line, widthFactor: 0.75),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(child: _bar(line, widthFactor: 0.4)),
              Container(
                width: 12,
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactMini(Color line, Color accent) {
    return Center(
      child: Row(
        children: [
          Expanded(child: _bar(line, widthFactor: 0.6)),
          const SizedBox(width: 6),
          Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMini(Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, _darken(accent, 0.22)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(Colors.white.withValues(alpha: 0.92), widthFactor: 0.6),
              const SizedBox(height: 4),
              _bar(Colors.white.withValues(alpha: 0.6), widthFactor: 0.35),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

class _SegItem {
  const _SegItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.accent,
  });

  final List<_SegItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 16,
                        color: i == selectedIndex
                            ? Colors.white
                            : MerchantPremiumColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: i == selectedIndex
                              ? Colors.white
                              : MerchantPremiumColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

/// Verdunkelt eine Farbe (für den Hero-Verlauf der Magazin-Vorlage).
Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
