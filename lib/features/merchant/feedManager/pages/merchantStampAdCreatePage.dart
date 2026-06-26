import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../stamps/widgets/stampCardVisual.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../shared/widgets/merchantUiComponents.dart';
import '../../stamps/models/stampCardModel.dart';
import '../../stamps/services/merchantStampsService.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../services/feedAiSuggestionService.dart';
import '../services/merchantFeedCreateService.dart';

/// Ready-made template that lets a merchant advertise a stamp card in seconds.
/// Almost everything is auto-generated: the merchant picks a card + a title and
/// subtitle, the ad visual is rendered live from the card's real design, and on
/// publish that visual is captured to a PNG (RepaintBoundary → toImage) and used
/// as the post image. The CTA points to the merchant's profile (add-to-wallet).
class MerchantStampAdCreatePage extends StatelessWidget {
  const MerchantStampAdCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => _StampAdProvider(
        stampsService: MerchantStampsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        feedService: MerchantFeedCreateService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
          aiSuggestionService: const FeedAiSuggestionService(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _StampAdView(),
    );
  }
}

class _StampAdProvider extends ChangeNotifier {
  _StampAdProvider({
    required this.stampsService,
    required this.feedService,
    required this.uploadService,
  });

  final MerchantStampsService stampsService;
  final MerchantFeedCreateService feedService;
  final UploadService uploadService;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<StampCardModel> cards = const [];

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final all = await stampsService.loadStampCards();
      // Only non-archived cards can be advertised (capped at 3 by the feature).
      cards = all.where((c) => !c.isArchivedCard).take(3).toList(growable: false);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Uploads the captured ad PNG and creates the stampAd post. Returns success.
  Future<bool> publishAd({
    required StampCardModel card,
    required String title,
    required String subtitle,
    required String description,
    required String ctaLabel,
    required Uint8List imageBytes,
  }) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final media = await uploadService.uploadOptimizedImageBytes(
        bytes: imageBytes,
        fileName: 'stamp-ad-${card.id}.png',
        type: UploadImageType.feedPost,
      );
      final imageUrl = media.secureUrl.isNotEmpty ? media.secureUrl : media.url;
      await feedService.createPost(
        type: 'stampAd',
        title: title,
        subtitle: subtitle,
        description: description,
        imageUrl: imageUrl,
        ctaLabel: ctaLabel,
        ctaType: 'primary',
        ctaLinkType: 'profile',
        linkedCardId: card.id,
        targetAudience: 'all',
      );
      return true;
    } catch (e) {
      error = _readable(e);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  String _readable(Object error) {
    final text = error.toString();
    const prefix = 'Bad state: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }
}

class _StampAdView extends StatefulWidget {
  const _StampAdView();

  @override
  State<_StampAdView> createState() => _StampAdViewState();
}

class _StampAdViewState extends State<_StampAdView> {
  final _boundaryKey = GlobalKey();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _description = TextEditingController();
  final _ctaLabel = TextEditingController();

  StampCardModel? _selected;
  bool _capturing = false;
  bool _prefilled = false;
  // The last captured snapshot — lets the merchant see the exact image that
  // will be published and regenerate it on demand.
  Uint8List? _snapshot;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _subtitle, _description, _ctaLabel]) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _description.dispose();
    _ctaLabel.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Pre-fills the editable template defaults once cards are known.
  void _prefillOnce(LanguageService texts) {
    if (_prefilled) return;
    _prefilled = true;
    _description.text = texts.text('merchant.stampAd.descriptionHint');
    _ctaLabel.text = texts.text('merchant.stampAd.ctaDefault');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<_StampAdProvider>();
    final texts = context.watch<LanguageService>();

    return MerchantToolScaffold(
      title: texts.text('merchant.stampAd.title'),
      subtitle: texts.text('merchant.stampAd.subtitle'),
      backPath: '/merchant/feed/manage',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.stampAd.tooltip')),
      child: provider.isLoading
          ? const MerchantLoadingCards()
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : provider.cards.isEmpty
                  ? _NoCardsState()
                  : _buildEditor(context, provider, texts),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    _StampAdProvider provider,
    LanguageService texts,
  ) {
    _prefillOnce(texts);
    _selected ??= provider.cards.first;
    final card = _selected!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card picker ──────────────────────────────────────────────────
        MerchantFormSection(
          title: texts.text('merchant.stampAd.pickCard'),
          tooltip: texts.text('merchant.stampAd.pickCardTip'),
          child: SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: provider.cards.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final c = provider.cards[index];
                final selected = c.id == card.id;
                return ChoiceChip(
                  label: Text(
                    c.title.isEmpty ? texts.text('merchant.stamps.untitled') : c.title,
                  ),
                  selected: selected,
                  selectedColor: MerchantPremiumColors.ink,
                  backgroundColor: MerchantPremiumColors.surfaceAlt,
                  side: BorderSide(
                    color: selected ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                  onSelected: (_) => setState(() {
                    _selected = c;
                    _snapshot = null; // card changed → previous snapshot is stale
                  }),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // ── Live WYSIWYG preview ─────────────────────────────────────────
        MerchantFormSection(
          title: texts.text('merchant.stampAd.preview'),
          tooltip: texts.text('merchant.stampAd.previewTip'),
          child: Center(
            child: FittedBox(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: _AdVisual(
                  card: card,
                  title: _title.text,
                  subtitle: _subtitle.text,
                  fallbackTitle: texts.text('merchant.stampAd.defaultTitle'),
                  footer: texts.text('merchant.stampAd.visualFooter'),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: _capturing ? null : () => _regenerate(texts),
            icon: _capturing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: MerchantPremiumColors.gold),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(texts.text('merchant.stampAd.regenerate')),
            style: TextButton.styleFrom(foregroundColor: MerchantPremiumColors.gold),
          ),
        ),
        if (_snapshot != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: MerchantPremiumColors.gold),
              const SizedBox(width: 6),
              Text(
                texts.text('merchant.stampAd.snapshotReady'),
                style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // ── Editable text (title required, rest pre-filled) ──────────────
        MerchantFormSection(
          title: texts.text('merchant.stampAd.texts'),
          tooltip: texts.text('merchant.stampAd.textsTip'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MerchantTextField(controller: _title, label: texts.text('merchant.stampAd.adTitle')),
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(controller: _subtitle, label: texts.text('merchant.stampAd.adSubtitle')),
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(
                controller: _description,
                label: texts.text('merchant.stampAd.adDescription'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(controller: _ctaLabel, label: texts.text('merchant.stampAd.ctaLabel')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: MerchantPremiumColors.surfaceAlt,
          child: Row(
            children: [
              const MerchantPremiumIconBox(icon: Icons.account_circle_rounded, size: 42),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  texts.text('merchant.stampAd.ctaInfo'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MerchantPrimaryButton(
          label: texts.text('merchant.stampAd.publish'),
          icon: Icons.send_rounded,
          isLoading: provider.isSaving || _capturing,
          onPressed: () => _publish(context, provider, texts),
        ),
      ],
    );
  }

  /// Captures the live preview to a PNG. Graceful: returns null on any failure
  /// (web rendering quirk, boundary not yet painted) so callers can retry
  /// instead of crashing.
  Future<Uint8List?> _capture() async {
    try {
      // Ensure the boundary has painted at least once (web first-capture quirk).
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _regenerate(LanguageService texts) async {
    setState(() => _capturing = true);
    final bytes = await _capture();
    if (!mounted) return;
    setState(() {
      _capturing = false;
      _snapshot = bytes;
    });
    if (bytes == null) {
      _toast(texts.text('merchant.stampAd.error.capture'));
    }
  }

  Future<void> _publish(
    BuildContext context,
    _StampAdProvider provider,
    LanguageService texts,
  ) async {
    if (provider.isSaving || _capturing) return;
    final card = _selected;
    if (card == null) return;
    if (_title.text.trim().isEmpty) {
      _toast(texts.text('merchant.stampAd.error.title'));
      return;
    }
    // Use the existing snapshot, or capture fresh now.
    setState(() => _capturing = true);
    final bytes = _snapshot ?? await _capture();
    if (!mounted) return;
    setState(() => _capturing = false);
    if (bytes == null) {
      _toast(texts.text('merchant.stampAd.error.capture'));
      return;
    }
    final ok = await provider.publishAd(
      card: card,
      title: _title.text,
      subtitle: _subtitle.text,
      description: _description.text,
      ctaLabel: _ctaLabel.text,
      imageBytes: bytes,
    );
    if (ok && context.mounted) {
      context.go('/merchant/feed/manage');
    } else if (context.mounted && provider.error != null) {
      _toast(provider.error!);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The square ad composition rendered from the card's live design. Captured to
/// a PNG on publish. Fixed 360×360 logical size → consistent, high-res output
/// regardless of screen size (the parent FittedBox only scales it for display).
class _AdVisual extends StatelessWidget {
  const _AdVisual({
    required this.card,
    required this.title,
    required this.subtitle,
    required this.fallbackTitle,
    required this.footer,
  });

  final StampCardModel card;
  final String title;
  final String subtitle;
  final String fallbackTitle;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final bg = _hex(card.backgroundColor, const Color(0xFF14171A));
    final accent = _hex(card.gradientColor, const Color(0xFF45C9A4));
    final fg = _hex(card.textColor, const Color(0xFFFEFFFC));
    final shownTitle = title.trim().isEmpty ? fallbackTitle : title.trim();

    return Container(
      width: 360,
      height: 360,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.black.withValues(alpha: 0.35), bg),
            Color.alphaBlend(accent.withValues(alpha: 0.30), bg),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shownTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 23,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.78),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Inner = the real card visual (single source of truth).
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 320,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: StampCardVisual(card: card),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, size: 16, color: fg.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    footer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCardsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantEmptyState(
      icon: Icons.card_giftcard_rounded,
      title: texts.text('merchant.stampAd.noCardsTitle'),
      message: texts.text('merchant.stampAd.noCardsMessage'),
      actionLabel: texts.text('merchant.stampAd.createCard'),
      onAction: () => context.go('/merchant/stamps'),
    );
  }
}

Color _hex(String value, Color fallback) {
  final clean = value.replaceAll('#', '');
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
