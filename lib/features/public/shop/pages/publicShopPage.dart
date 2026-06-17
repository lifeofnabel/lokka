import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/translatorService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../merchant/catalog/models/itemOptionGroup.dart';
import '../../../merchant/catalog/models/itemTagData.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import '../../../merchant/catalog/models/runnerData.dart';
import '../providers/publicShopProvider.dart';
import '../services/publicShopService.dart';
import '../widgets/publicShopActionBar.dart';
import '../widgets/publicShopContactRail.dart';
import '../widgets/publicShopFooter.dart';
import '../widgets/publicShopHero.dart';
import '../widgets/publicShopItemCard.dart';
import '../widgets/publicShopTheme.dart';
import 'publicMyOrdersPage.dart';

class PublicShopPage extends StatelessWidget {
  const PublicShopPage({
    super.key,
    required this.merchantId,
    this.tableId = '',
  });

  final String merchantId;
  final String tableId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PublicShopProvider(
        service: PublicShopService(
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(merchantId: merchantId, tableId: tableId),
      child: _PublicShopView(merchantId: merchantId),
    );
  }
}

class _PublicShopView extends StatefulWidget {
  const _PublicShopView({required this.merchantId});

  final String merchantId;

  @override
  State<_PublicShopView> createState() => _PublicShopViewState();
}

class _PublicShopViewState extends State<_PublicShopView> {
  /// Kunden-Override; ist null, gilt das Merchant-Design (Standard).
  bool? _darkOverride;

  // Sprach-Umschalter (Live-Übersetzung wie Qoucher). 'original' = aus.
  String _language = 'original';
  final Map<String, String> _translations = {};
  final Set<String> _pendingTranslations = {};

  /// Verhindert, dass die „Wer geht rein?"-Abfrage (Runner-Modus) mehrfach
  /// geplant wird.
  bool _runnerPromptScheduled = false;

  /// Übersetzt [text] in die gewählte Sprache (gecacht). Gibt das Original
  /// zurück, solange die Übersetzung lädt oder 'original' aktiv ist.
  String _tr(String key, String text) {
    if (_language == 'original' || text.trim().isEmpty) return text;
    final cacheKey = '$_language::$key';
    final cached = _translations[cacheKey];
    if (cached != null) return cached;
    if (!_pendingTranslations.contains(cacheKey)) {
      _pendingTranslations.add(cacheKey);
      TranslatorService.translate(text: text, targetLang: _language).then((value) {
        if (!mounted) return;
        setState(() {
          _translations[cacheKey] = value;
          _pendingTranslations.remove(cacheKey);
        });
      });
    }
    return text;
  }

  Future<void> _pickLanguage(PublicShopPalette palette) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in TranslatorService.supportedLanguages.entries)
              ListTile(
                title: Text(
                  entry.value,
                  style: TextStyle(color: palette.ink, fontWeight: FontWeight.w800),
                ),
                trailing: entry.key == _language
                    ? Icon(Icons.check_rounded, color: palette.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _language = selected);
  }

  /// Runner-Modus: direkt fragen, wer gerade bedient (verfügbare Runner +
  /// „Zuschauer"), ohne PIN/Login. Auswahl `null` = Zuschauer (nur ansehen).
  Future<void> _pickRunner(
    PublicShopProvider provider,
    PublicShopPalette palette,
  ) async {
    final texts = context.read<LanguageService>();
    final available = provider.availableRunners;
    final chosen = await showModalBottomSheet<RunnerData>(
      context: context,
      backgroundColor: palette.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                texts.text('public.shop.runnerPickTitle'),
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final runner in available)
              ListTile(
                leading:
                    Icon(Icons.directions_run_rounded, color: palette.accent),
                title: Text(
                  runner.name,
                  style:
                      TextStyle(color: palette.ink, fontWeight: FontWeight.w800),
                ),
                trailing: provider.activeRunner?.id == runner.id
                    ? Icon(Icons.check_rounded, color: palette.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(runner),
              ),
            Divider(color: palette.line, height: 1),
            ListTile(
              leading: Icon(Icons.visibility_rounded, color: palette.muted),
              title: Text(
                texts.text('public.shop.runnerViewer'),
                style:
                    TextStyle(color: palette.ink, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                texts.text('public.shop.runnerViewerHint'),
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              trailing: (provider.runnerChosen && provider.activeRunner == null)
                  ? Icon(Icons.check_rounded, color: palette.accent)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(), // null = Zuschauer
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted) return;
    // chosen == null → Zuschauer (auch beim Wegtippen); als gewählt markieren.
    provider.selectRunner(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicShopProvider>();
    final texts = context.watch<LanguageService>();
    final dark = _darkOverride ?? provider.design.darkMode;
    final palette = PublicShopPalette(dark: dark, accent: provider.design.accent);
    final Widget content;

    if (provider.isLoading) {
      content = _PublicLoading(palette: palette);
    } else if (provider.error != null) {
      content = _PublicError(message: provider.error!, palette: palette);
    } else if (provider.merchant == null) {
      content = _PublicEmpty(
        title: texts.text('public.shop.notFoundTitle'),
        message: texts.text('public.shop.notFoundMessage'),
        palette: palette,
      );
    } else if (!provider.catalogAvailable) {
      content = _PublicEmpty(
        title: texts.text('public.shop.catalogDisabledTitle'),
        message: texts.text('public.shop.catalogDisabledMessage'),
        palette: palette,
      );
    } else {
      content = Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
            children: [
              _PublicTopControls(
                darkMode: dark,
                palette: palette,
                language: _language,
                onLanguageTap: () => _pickLanguage(palette),
                onToggleTheme: () => setState(() => _darkOverride = !dark),
              ),
              const SizedBox(height: AppSpacing.md),
              PublicShopHero(
                merchant: provider.merchant!,
                tableLabel: provider.table?.label ?? '',
                darkMode: dark,
                footer: _heroHasContact(provider.merchant!)
                    ? PublicShopContactRail(merchant: provider.merchant!, palette: palette)
                    : null,
              ),
              if (provider.catalogConfig.modeRunner) ...[
                const SizedBox(height: AppSpacing.md),
                _RunnerBar(
                  palette: palette,
                  onSwitch: () => _pickRunner(provider, palette),
                ),
              ],
              if ((provider.merchant!['publicNotice'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _PublicNoticeCard(
                  notice: _tr('notice', (provider.merchant!['publicNotice'] ?? '').toString()),
                  palette: palette,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (provider.catalogConfig.modeRunner) ...[
                _RunnerSearchBar(palette: palette),
                const SizedBox(height: AppSpacing.md),
              ],
              _CategoryBar(provider: provider, palette: palette, translate: _tr),
              const SizedBox(height: AppSpacing.md),
              _buildItems(provider, palette, texts),
              const SizedBox(height: AppSpacing.lg),
              // Runner-Modus mit gewähltem Mitarbeiter: „Meine Bestellungen"
              // statt Impressum.
              if (provider.catalogConfig.modeRunner &&
                  provider.activeRunner != null)
                _MyOrdersCard(
                  palette: palette,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicMyOrdersPage(
                        palette: palette,
                        merchantId: widget.merchantId,
                        runnerId: provider.activeRunner!.id,
                      ),
                    ),
                  ),
                )
              else
                PublicShopFooter(
                    merchant: provider.merchant!, palette: palette),
            ],
          ),
          if (provider.canOrder)
            Align(
              alignment: Alignment.bottomCenter,
              child: PublicShopActionBar(
                provider: provider,
                palette: palette,
                merchantId: widget.merchantId,
              ),
            ),
        ],
      );
    }

    // Runner-Modus: beim ersten Anzeigen direkt fragen, wer reingeht.
    if (provider.catalogConfig.modeRunner &&
        !provider.runnerChosen &&
        !_runnerPromptScheduled &&
        !provider.isLoading &&
        provider.merchant != null &&
        provider.catalogAvailable) {
      _runnerPromptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pickRunner(context.read<PublicShopProvider>(), palette);
      });
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Directionality(
          textDirection: TranslatorService.isRtl(_language)
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: content,
        ),
      ),
    );
  }

  /// Artikel je nach Merchant-Vorlage und Spaltenzahl rendern.
  Widget _buildItems(
    PublicShopProvider provider,
    PublicShopPalette palette,
    LanguageService texts,
  ) {
    final items = provider.visibleItems;
    if (items.isEmpty) {
      return _PublicEmpty(
        title: texts.text('public.shop.emptyTitle'),
        message: texts.text('public.shop.emptyMessage'),
        palette: palette,
      );
    }
    final layout = provider.design.layout;
    final cols = provider.design.safeColumns;

    Widget card(MerchantItemData item, bool grid) => PublicShopItemCard(
          item: item,
          palette: palette,
          layout: layout,
          texts: texts,
          tags: provider.itemTags,
          canOrder: provider.canOrder,
          grid: grid,
          translate: _tr,
          onTap: () => _openItemSheet(
            context,
            item: item,
            canOrder: provider.canOrder,
            palette: palette,
          ),
          onAdd: () => provider.addItem(item),
        );

    if (cols == 2) {
      final rows = <Widget>[];
      for (var i = 0; i < items.length; i += 2) {
        final left = items[i];
        final right = i + 1 < items.length ? items[i + 1] : null;
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card(left, true)),
              const SizedBox(width: 12),
              Expanded(
                child: right == null ? const SizedBox.shrink() : card(right, true),
              ),
            ],
          ),
        ));
      }
      return Column(children: rows);
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: card(item, false),
          ),
      ],
    );
  }
}

/// Runner-Modus: zeigt, wer gerade bedient (Runner oder „Zuschauer"), und
/// erlaubt direktes Wechseln per Auswahl-Sheet – ohne PIN/Login.
class _RunnerBar extends StatelessWidget {
  const _RunnerBar({required this.palette, required this.onSwitch});

  final PublicShopPalette palette;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<PublicShopProvider>();
    final runner = provider.activeRunner;
    final isViewer = runner == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isViewer ? Icons.visibility_rounded : Icons.directions_run_rounded,
            color: palette.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts.text('public.shop.runnerActiveLabel'),
                  style: TextStyle(
                    color: palette.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  isViewer
                      ? texts.text('public.shop.runnerViewer')
                      : runner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onSwitch,
            icon: Icon(Icons.swap_horiz_rounded, color: palette.accent, size: 18),
            label: Text(
              texts.text('public.shop.runnerSwitch'),
              style: TextStyle(color: palette.accent, fontWeight: FontWeight.w900),
            ),
            style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ],
      ),
    );
  }
}

/// Stabile Suchleiste in der Karte (nur Runner-Modus): schnelles Finden von
/// Artikeln über Name oder Artikelnummer.
class _RunnerSearchBar extends StatefulWidget {
  const _RunnerSearchBar({required this.palette});

  final PublicShopPalette palette;

  @override
  State<_RunnerSearchBar> createState() => _RunnerSearchBarState();
}

class _RunnerSearchBarState extends State<_RunnerSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final palette = widget.palette;
    final provider = context.read<PublicShopProvider>();
    return TextField(
      controller: _controller,
      onChanged: (value) {
        provider.setItemSearch(value);
        setState(() {}); // Clear-Button ein-/ausblenden
      },
      style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: texts.text('public.shop.searchItems'),
        hintStyle: TextStyle(color: palette.muted, fontWeight: FontWeight.w600),
        prefixIcon: Icon(Icons.search_rounded, color: palette.muted),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: palette.muted),
                onPressed: () {
                  _controller.clear();
                  provider.setItemSearch('');
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: palette.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
      ),
    );
  }
}

/// „Meine Bestellungen"-Karte am Fuß der Karte (statt Impressum) – nur im
/// Runner-Modus, wenn ein Mitarbeiter gewählt ist.
class _MyOrdersCard extends StatelessWidget {
  const _MyOrdersCard({required this.palette, required this.onTap});

  final PublicShopPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.receipt_long_rounded, color: palette.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texts.text('public.shop.myOrders'),
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      texts.text('public.shop.myOrdersHint'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicTopControls extends StatelessWidget {
  const _PublicTopControls({
    required this.darkMode,
    required this.palette,
    required this.language,
    required this.onLanguageTap,
    required this.onToggleTheme,
  });

  final bool darkMode;
  final PublicShopPalette palette;
  final String language;
  final VoidCallback onLanguageTap;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final langLabel = language == 'original'
        ? texts.text('public.shop.language')
        : (TranslatorService.supportedLanguages[language] ?? language);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu_rounded, color: palette.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    texts.text('public.shop.menu'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onLanguageTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: language == 'original'
                      ? palette.line
                      : palette.accent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: palette.accent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    langLabel,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: palette.card,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onToggleTheme,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.line),
              ),
              child: Icon(
                darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: palette.ink,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicNoticeCard extends StatelessWidget {
  const _PublicNoticeCard({required this.notice, required this.palette});

  final String notice;
  final PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.info_outline_rounded, color: palette.background, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              notice,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.background,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.provider,
    required this.palette,
    required this.translate,
  });

  final PublicShopProvider provider;
  final PublicShopPalette palette;
  final String Function(String key, String text) translate;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CategoryChip(
            label: translate('cat_all', texts.text('common.all')),
            selected: provider.selectedCategoryId == 'all',
            palette: palette,
            onTap: () => provider.selectCategory('all'),
          ),
          ...provider.categories.map(
            (category) => _CategoryChip(
              label: translate('cat_${category.id}', category.name),
              selected: provider.selectedCategoryId == category.id,
              palette: palette,
              onTap: () => provider.selectCategory(category.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final PublicShopPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? palette.accent : palette.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.onAccent : palette.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

void _openItemSheet(
  BuildContext context, {
  required MerchantItemData item,
  required bool canOrder,
  required PublicShopPalette palette,
}) {
  final texts = context.read<LanguageService>();
  final provider = context.read<PublicShopProvider>();
  final noteController = TextEditingController();
  // Auswahl je Gruppe (Option-IDs).
  final selectedByGroup = <String, Set<String>>{
    for (final group in item.optionGroups) group.id: <String>{},
  };

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        num surcharge = 0;
        for (final group in item.optionGroups) {
          for (final option in group.options) {
            if (selectedByGroup[group.id]!.contains(option.id)) {
              surcharge += option.price;
            }
          }
        }
        final total = item.price + surcharge;
        final missingRequired = item.optionGroups.any(
          (group) => group.isRequired && (selectedByGroup[group.id]?.isEmpty ?? true),
        );

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: item.isWideImage ? 16 / 9 : 1.6,
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: palette.soft,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: item.imageUrl.isEmpty
                                  ? Icon(Icons.restaurant_menu_rounded, color: palette.muted, size: 42)
                                  : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (item.categoryName.isNotEmpty)
                                _TinyShopChip(label: item.categoryName, palette: palette),
                              if (item.articleNumber.isNotEmpty)
                                _TinyShopChip(label: '#${item.articleNumber}', palette: palette),
                              _ItemTagChips(item: item, tags: provider.itemTags, palette: palette),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            item.name,
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            Text(
                              item.description,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 14.5,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          // Optionsgruppen
                          for (final group in item.optionGroups)
                            _SheetOptionGroup(
                              group: group,
                              palette: palette,
                              texts: texts,
                              selected: selectedByGroup[group.id]!,
                              onToggle: (optionId) => setSheetState(() {
                                final set = selectedByGroup[group.id]!;
                                if (group.multiSelect) {
                                  if (set.contains(optionId)) {
                                    set.remove(optionId);
                                  } else {
                                    set.add(optionId);
                                  }
                                } else {
                                  set
                                    ..clear()
                                    ..add(optionId);
                                }
                              }),
                            ),
                          if (canOrder) ...[
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: noteController,
                              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: texts.text('public.shop.itemNote'),
                                hintText: texts.text('public.shop.itemNoteHint'),
                                labelStyle: TextStyle(color: palette.muted),
                                hintStyle: TextStyle(color: palette.muted.withValues(alpha: 0.7)),
                                filled: true,
                                fillColor: palette.soft,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: palette.line),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: palette.line),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: palette.accent, width: 1.4),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _price(total, texts),
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (canOrder)
                        FilledButton.icon(
                          onPressed: missingRequired
                              ? null
                              : () {
                                  final options = <ItemOption>[];
                                  for (final group in item.optionGroups) {
                                    for (final option in group.options) {
                                      if (selectedByGroup[group.id]!.contains(option.id)) {
                                        options.add(option);
                                      }
                                    }
                                  }
                                  provider.addConfiguredItem(
                                    item: item,
                                    options: options,
                                    note: noteController.text,
                                  );
                                  Navigator.of(sheetContext).pop();
                                },
                          icon: const Icon(Icons.add_rounded),
                          label: Text(
                            missingRequired
                                ? texts.text('public.shop.chooseRequired')
                                : texts.text('public.shop.add'),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: palette.onAccent,
                            disabledBackgroundColor: palette.soft,
                            minimumSize: const Size(140, 52),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ).whenComplete(noteController.dispose);
}

/// Eine Optionsgruppe im Artikel-Sheet (Einzel- oder Mehrfachauswahl).
class _SheetOptionGroup extends StatelessWidget {
  const _SheetOptionGroup({
    required this.group,
    required this.palette,
    required this.texts,
    required this.selected,
    required this.onToggle,
  });

  final ItemOptionGroup group;
  final PublicShopPalette palette;
  final LanguageService texts;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: TextStyle(color: palette.ink, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (group.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    texts.text('public.shop.required'),
                    style: TextStyle(color: palette.accent, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final option in group.options)
            GestureDetector(
              onTap: () => onToggle(option.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected.contains(option.id) ? palette.accent : palette.line,
                    width: selected.contains(option.id) ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      group.multiSelect
                          ? (selected.contains(option.id)
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded)
                          : (selected.contains(option.id)
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                      color: selected.contains(option.id) ? palette.accent : palette.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option.name,
                        style: TextStyle(color: palette.ink, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (option.price > 0)
                      Text(
                        '+ ${_price(option.price, texts)}',
                        style: TextStyle(color: palette.accent, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PublicLoading extends StatelessWidget {
  const _PublicLoading({required this.palette});

  final PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        5,
        (index) => Container(
          height: index == 0 ? 220 : 104,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: palette.line),
          ),
        ),
      ),
    );
  }
}

class _PublicError extends StatelessWidget {
  const _PublicError({required this.message, required this.palette});

  final String message;
  final PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _PublicEmpty(
          title: texts.text('common.errorTitle'),
          message: texts.text(message.replaceFirst('Bad state: ', '')),
          palette: palette,
        ),
      ),
    );
  }
}

class _PublicEmpty extends StatelessWidget {
  const _PublicEmpty({
    required this.title,
    required this.message,
    required this.palette,
  });

  final String title;
  final String message;
  final PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_rounded, size: 42, color: palette.ink),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.ink, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ItemTagChips extends StatelessWidget {
  const _ItemTagChips({
    required this.item,
    required this.tags,
    required this.palette,
  });

  final MerchantItemData item;
  final List<ItemTagData> tags;
  final PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    final selected = tags
        .where((tag) => item.allergenIds.contains(tag.id) || item.additiveIds.contains(tag.id))
        .toList();
    if (selected.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: selected
          .map(
            (tag) => Tooltip(
              message: tag.name,
              child: _TinyShopChip(label: tag.code, palette: palette),
            ),
          )
          .toList(),
    );
  }
}

class _TinyShopChip extends StatelessWidget {
  const _TinyShopChip({required this.label, required this.palette});

  final String label;
  final PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}

/// Gibt es überhaupt Kontakt-/Öffnungszeiten-Daten für die Cover-Leiste?
bool _heroHasContact(Map<String, dynamic> merchant) {
  final social = merchant['socialLinks'];
  final hasSocial = social is Map &&
      social.values.any((value) => (value?.toString().trim().isNotEmpty ?? false));
  final hours = merchant['openingHours'];
  final hasHours = hours is Map && hours.isNotEmpty;
  bool has(String key) => (merchant[key]?.toString().trim().isNotEmpty ?? false);
  return has('phone') ||
      has('address') ||
      has('fullAddress') ||
      hasSocial ||
      hasHours;
}
