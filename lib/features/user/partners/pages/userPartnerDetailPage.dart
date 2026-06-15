import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/partners/pages/userMenuPage.dart';
import 'package:lokka/features/user/partners/pages/userPartnerPointsPage.dart';
import 'package:lokka/features/user/partners/pages/userPartnerStampsPage.dart';
import 'package:lokka/features/user/partners/services/userLoyaltyService.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

/// Partner-Detail im Instagram-Stil: großes Cover mit Floating-Buttons,
/// zentrierter Profil-Topper, swipebare Mini-Cards mit Popouts,
/// Treue-Highlights und darunter der Partner-Feed.
class UserPartnerDetailPage extends StatefulWidget {
  const UserPartnerDetailPage({super.key, required this.merchant});

  final PublicMerchantUserModel merchant;

  @override
  State<UserPartnerDetailPage> createState() => _UserPartnerDetailPageState();
}

enum _PartnerFeedSort { newest, hottest }

/// Beitrag + aggregierte Bewertung aus den Post-Reviews.
class _PartnerPost {
  const _PartnerPost({
    required this.post,
    required this.avgRating,
    required this.ratingCount,
  });

  final FeedPostModel post;
  final double? avgRating;
  final int ratingCount;

  bool get isExpired =>
      post.validUntil != null && post.validUntil!.isBefore(DateTime.now());
}

class _UserPartnerDetailPageState extends State<UserPartnerDetailPage> {
  late final FirestoreService _firestore;
  late final UserWalletService _walletService;
  late final UserLoyaltyService _loyaltyService;

  bool _isInWallet = false;
  bool _isCheckingWallet = true;
  bool _isAdding = false;

  // Bewertungspille = Schnitt aller Post-Bewertungen dieses Partners.
  double? _avgRating;
  int _ratingCount = 0;

  // Partner-Feed
  List<_PartnerPost> _posts = const [];
  bool _postsLoading = true;
  _PartnerFeedSort _sort = _PartnerFeedSort.newest;
  bool _showExpired = false;

  // Treue-Programme
  LoyaltyInfo _loyalty = LoyaltyInfo.none;

  @override
  void initState() {
    super.initState();
    _firestore = context.read<FirestoreService>();
    _walletService = UserWalletService(
      firestoreService: _firestore,
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
    _loyaltyService = UserLoyaltyService(firestoreService: _firestore);
    _checkWallet();
    _loadPartnerFeed();
    _loadLoyalty();
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
        _snack('${widget.merchant.shopName} zur Wallet hinzugefügt');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAdding = false);
        _snack('Fehler beim Hinzufügen. Bitte erneut versuchen.', error: true);
      }
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  // ── Daten laden ────────────────────────────────────────────────────────────

  /// Lädt alle Beiträge des Partners aus dem globalen Feed (client-seitig
  /// gefiltert, kein Composite-Index nötig) und parallel dazu die
  /// Durchschnittsbewertung jedes Beitrags aus dessen feedReviews.
  Future<void> _loadPartnerFeed() async {
    try {
      final snap = await _firestore
          .collection(FirebasePaths.feed)
          .orderBy('publishedAt', descending: true)
          .get();
      final posts = snap.docs
          .where((doc) {
            final d = doc.data();
            return d['merchantId'] == widget.merchant.merchantId &&
                d['isArchived'] != true &&
                d['isPrivate'] != true;
          })
          .map((doc) => FeedPostModel.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();

      final enriched = await Future.wait(posts.map(_loadPostRating));
      if (!mounted) return;

      final rated = enriched.where((e) => e.avgRating != null).toList();
      setState(() {
        _posts = enriched;
        _postsLoading = false;
        _ratingCount = enriched.fold<int>(0, (sum, e) => sum + e.ratingCount);
        _avgRating = rated.isEmpty
            ? null
            : rated.map((e) => e.avgRating!).reduce((a, b) => a + b) /
                rated.length;
      });
    } catch (_) {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<_PartnerPost> _loadPostRating(FeedPostModel post) async {
    try {
      final snap = await _firestore
          .collection(FirebasePaths.feedReviews(post.postId))
          .get();
      final ratings = snap.docs
          .map((d) => (d.data()['rating'] as num?)?.toDouble())
          .whereType<double>()
          .where((r) => r >= 1 && r <= 5)
          .toList();
      final avg = ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length;
      return _PartnerPost(
          post: post, avgRating: avg, ratingCount: ratings.length);
    } catch (_) {
      return _PartnerPost(post: post, avgRating: null, ratingCount: 0);
    }
  }

  Future<void> _loadLoyalty() async {
    try {
      final info =
          await _loyaltyService.fetchLoyaltyInfo(widget.merchant.merchantId);
      if (mounted) setState(() => _loyalty = info);
    } catch (_) {}
  }

  List<_PartnerPost> get _visiblePosts {
    final list =
        _posts.where((e) => _showExpired || !e.isExpired).toList();
    if (_sort == _PartnerFeedSort.newest) {
      DateTime key(_PartnerPost e) =>
          e.post.publishedAt ?? e.post.createdAt ?? DateTime(2000);
      list.sort((a, b) => key(b).compareTo(key(a)));
    } else {
      double score(_PartnerPost e) =>
          e.post.likesCount * 10 + (e.avgRating ?? 0) * 20;
      list.sort((a, b) => score(b).compareTo(score(a)));
    }
    return list;
  }

  // ── Cover-Aktionen ─────────────────────────────────────────────────────────

  void _openGallery() {
    final images = widget.merchant.galleryImages;
    if (images.isEmpty) return;
    showPartnerPopout(
      context,
      icon: Icons.photo_library_rounded,
      title: 'Bilder',
      child: _GalleryPager(images: images),
    );
  }

  void _openCoverZoom() {
    final url = widget.merchant.coverUrl;
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _CoverCircleButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Schließen',
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Swipe-Card-Aktionen (süße Popouts) ─────────────────────────────────────

  void _openRoute() {
    final m = widget.merchant;
    showPartnerPopout(
      context,
      icon: Icons.location_on_rounded,
      title: 'Adresse',
      child: _PopoutColumn(
        children: [
          _PopoutText(m.fullAddress.isNotEmpty ? m.fullAddress : m.address),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _launchMaps();
            },
            icon: const Icon(Icons.directions_rounded, size: 18),
            label: const Text('In Karten öffnen'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMaps() async {
    final m = widget.merchant;
    final query = m.hasCoordinates
        ? '${m.lat},${m.lng}'
        : Uri.encodeComponent(
            m.fullAddress.isNotEmpty ? m.fullAddress : m.address);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Karten-App konnte nicht geöffnet werden');
    }
  }

  void _openHours() {
    showPartnerPopout(
      context,
      icon: Icons.schedule_rounded,
      title: 'Öffnungszeiten',
      child: _HoursList(hours: widget.merchant.openingHours ?? const {}),
    );
  }

  void _openMenu() {
    final m = widget.merchant;
    final hasIntegrated = m.menuIntegratedEnabled;
    final hasExternal = m.hasExternalMenu;
    if (hasIntegrated && !hasExternal) {
      _openIntegratedMenu();
    } else if (hasExternal && !hasIntegrated) {
      _launchExternalMenu();
    } else {
      showPartnerPopout(
        context,
        icon: Icons.restaurant_menu_rounded,
        title: 'Speisekarte',
        child: _PopoutColumn(
          children: [
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openIntegratedMenu();
              },
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Speisekarte ansehen'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchExternalMenu();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Zur Web-Speisekarte'),
            ),
          ],
        ),
      );
    }
  }

  void _openIntegratedMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserMenuPage(
          merchantId: widget.merchant.merchantId,
          shopName: widget.merchant.shopName,
          tablesEnabled: widget.merchant.featuresPublic.contains('tables'),
          style: widget.merchant.menuStyle,
        ),
      ),
    );
  }

  Future<void> _launchExternalMenu() async {
    var url = (widget.merchant.menuExternalUrl ?? '').trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      if (mounted) _snack('Link konnte nicht geöffnet werden');
    }
  }

  Future<void> _call() async {
    final phone = widget.merchant.phone.trim();
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) _snack('Anruf nicht möglich');
    }
  }

  static const _socialMeta = <(String, String, IconData)>[
    ('website', 'Website', Icons.language_rounded),
    ('instagram', 'Instagram', Icons.camera_alt_rounded),
    ('tiktok', 'TikTok', Icons.music_note_rounded),
    ('facebook', 'Facebook', Icons.facebook),
  ];

  void _openSocial() {
    final links = widget.merchant.socialLinks;
    if (links.isEmpty) return;
    showPartnerPopout(
      context,
      icon: Icons.alternate_email_rounded,
      title: 'Social Media',
      child: _PopoutColumn(
        children: [
          for (final (key, label, icon) in _socialMeta)
            if ((links[key] ?? '').isNotEmpty)
              _SocialLinkRow(
                icon: icon,
                label: label,
                onTap: () {
                  Navigator.pop(context);
                  _launchSocialLink(links[key]!);
                },
              ),
        ],
      ),
    );
  }

  Future<void> _launchSocialLink(String url) async {
    var u = url.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Link konnte nicht geöffnet werden');
    }
  }

  // ── Treue-Programme ────────────────────────────────────────────────────────

  void _openPoints() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPartnerPointsPage(
          merchantId: widget.merchant.merchantId,
          shopName: widget.merchant.shopName,
        ),
      ),
    );
  }

  void _openStamps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPartnerStampsPage(
          merchantId: widget.merchant.merchantId,
          shopName: widget.merchant.shopName,
          merchant: widget.merchant,
        ),
      ),
    );
  }

  List<_SwipeCardData> _swipeCards() {
    final m = widget.merchant;
    return [
      if (m.address.isNotEmpty || m.hasCoordinates)
        _SwipeCardData(Icons.near_me_rounded, 'Route', _openRoute),
      if (m.openingHours != null && m.openingHours!.isNotEmpty)
        _SwipeCardData(Icons.schedule_rounded, 'Zeiten', _openHours),
      if (m.phone.isNotEmpty)
        _SwipeCardData(Icons.call_rounded, 'Anrufen', _call),
      if (m.hasMenu)
        _SwipeCardData(Icons.restaurant_menu_rounded, 'Karte', _openMenu),
      if (m.socialLinks.isNotEmpty)
        _SwipeCardData(Icons.alternate_email_rounded, 'Social', _openSocial),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _CenteredHero(
              merchant: widget.merchant,
              avgRating: _avgRating,
              ratingCount: _ratingCount,
              onBack: () => Navigator.pop(context),
              onGallery:
                  widget.merchant.galleryImages.isNotEmpty ? _openGallery : null,
              onZoom:
                  widget.merchant.coverUrl.isNotEmpty ? _openCoverZoom : null,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
              child: Column(
                children: [
                  _WalletButton(
                    isInWallet: _isInWallet,
                    isChecking: _isCheckingWallet,
                    isAdding: _isAdding,
                    onAdd: _addToWallet,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SwipeCardsRow(cards: _swipeCards()),
                  if (_loyalty.hasAny) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        if (_loyalty.hasPoints)
                          Expanded(
                            child: _LoyaltyCard(
                              icon: Icons.stars_rounded,
                              title: 'Punkte sammeln',
                              onTap: _openPoints,
                            ),
                          ),
                        if (_loyalty.hasPoints && _loyalty.hasStamps)
                          const SizedBox(width: 10),
                        if (_loyalty.hasStamps)
                          Expanded(
                            child: _LoyaltyCard(
                              icon: Icons.approval_rounded,
                              title: 'Stempelkarte',
                              onTap: _openStamps,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _buildFeedSection(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Partner-Feed ───────────────────────────────────────────────────────────

  Widget _buildFeedSection() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final visible = _visiblePosts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Beiträge',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Tooltip(
              message: _showExpired
                  ? 'Abgelaufene ausblenden'
                  : 'Abgelaufene anzeigen',
              child: IconButton(
                onPressed: () => setState(() => _showExpired = !_showExpired),
                icon: const Icon(Icons.history_toggle_off_rounded, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor:
                      _showExpired ? cs.secondaryContainer : Colors.transparent,
                  foregroundColor: _showExpired
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _SortPill(
              label: 'Neueste',
              selected: _sort == _PartnerFeedSort.newest,
              onTap: () => setState(() => _sort = _PartnerFeedSort.newest),
            ),
            const SizedBox(width: 8),
            _SortPill(
              label: 'Heißeste',
              selected: _sort == _PartnerFeedSort.hottest,
              onTap: () => setState(() => _sort = _PartnerFeedSort.hottest),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_postsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_posts.isEmpty)
          Text(
            'Noch keine Beiträge.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else if (visible.isEmpty)
          Text(
            'Keine aktuellen Beiträge. Abgelaufene über den Filter einblenden.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          ...visible.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _PartnerPostCard(
                entry: entry,
                onTap: () => context.push(
                  '/user/feed/${entry.post.postId}',
                  extra: entry.post,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Zentrierter Profil-Topper (Instagram-Style) ──────────────────────────────

class _CenteredHero extends StatelessWidget {
  const _CenteredHero({
    required this.merchant,
    required this.onBack,
    this.onGallery,
    this.onZoom,
    this.avgRating,
    this.ratingCount = 0,
  });

  final PublicMerchantUserModel merchant;
  final VoidCallback onBack;
  final VoidCallback? onGallery;
  final VoidCallback? onZoom;
  final double? avgRating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initials = merchant.shopName.trim().isNotEmpty
        ? merchant.shopName.trim()[0].toUpperCase()
        : '?';
    final subtitle = [merchant.displayCity, merchant.shopType]
        .where((v) => v.isNotEmpty)
        .join(' · ');

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: merchant.coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: merchant.coverUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _coverFallback(),
                      )
                    : _coverFallback(),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.26),
                      ],
                      stops: const [0, 0.4, 1],
                    ),
                  ),
                ),
              ),
              // Floating-Back-Button auf dem Cover
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _CoverCircleButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Zurück',
                      onTap: onBack,
                    ),
                  ),
                ),
              ),
              // Galerie + Zoom unten rechts
              Positioned(
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    if (onGallery != null) ...[
                      _CoverCircleButton(
                        icon: Icons.photo_library_rounded,
                        tooltip: 'Mehr Bilder',
                        onTap: onGallery!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (onZoom != null)
                      _CoverCircleButton(
                        icon: Icons.fullscreen_rounded,
                        tooltip: 'Vergrößern',
                        onTap: onZoom!,
                      ),
                  ],
                ),
              ),
              Positioned(
                bottom: -46,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: merchant.logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: merchant.logoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                _logoFallback(cs, tt, initials),
                          )
                        : _logoFallback(cs, tt, initials),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            merchant.shopName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (avgRating != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: AppColors.googleYellow),
                const SizedBox(width: 4),
                Text(
                  '${avgRating!.toStringAsFixed(1)}  ·  $ratingCount',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _coverFallback() => const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.mintGradient));

  Widget _logoFallback(ColorScheme cs, TextTheme tt, String initials) =>
      Container(
        color: cs.secondaryContainer,
        alignment: Alignment.center,
        child: Text(
          initials,
          style: tt.headlineSmall?.copyWith(
            color: cs.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Kleiner runder Floating-Button auf dem Cover (dunkel transluzent).
class _CoverCircleButton extends StatelessWidget {
  const _CoverCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── Galerie-Popout ───────────────────────────────────────────────────────────

class _GalleryPager extends StatefulWidget {
  const _GalleryPager({required this.images});

  final List<String> images;

  @override
  State<_GalleryPager> createState() => _GalleryPagerState();
}

class _GalleryPagerState extends State<_GalleryPager> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppColors.gray100),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.gray100,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppColors.gray300, size: 40),
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _index ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Social-Link-Zeile im Popout ──────────────────────────────────────────────

class _SocialLinkRow extends StatelessWidget {
  const _SocialLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(icon, size: 19, color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style:
                        tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.open_in_new_rounded,
                    size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Treue-Highlight-Karte (grün tonal) ───────────────────────────────────────

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.secondaryContainer,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: cs.primary),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Jetzt ansehen',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSecondaryContainer
                          .withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 16,
                      color:
                          cs.onSecondaryContainer.withValues(alpha: 0.75)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sortier-Pille ────────────────────────────────────────────────────────────

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: selected ? cs.secondaryContainer : cs.surface,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? Colors.transparent : cs.outlineVariant,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? cs.onSecondaryContainer
                    : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Partner-Feed-Karte (gleiche Bildsprache wie der Für-dich-Feed) ───────────

class _PartnerPostCard extends StatelessWidget {
  const _PartnerPostCard({required this.entry, required this.onTap});

  final _PartnerPost entry;
  final VoidCallback onTap;

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final post = entry.post;
    final expired = entry.isExpired;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget image = post.imageUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: post.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: AppColors.gray100),
            errorWidget: (_, _, _) => Container(color: AppColors.gray100),
          )
        : Container(color: AppColors.gray100);
    if (expired) {
      image = ColorFiltered(colorFilter: _greyscale, child: image);
    }

    return Opacity(
      opacity: expired ? 0.75 : 1,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bild-Hero mit Titel-Overlay auf Scrim
                Stack(
                  children: [
                    AspectRatio(aspectRatio: 1.1, child: image),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              stops: const [0.5, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _TypeBadge(label: _feedTypeLabel(post.type)),
                    ),
                    if (expired)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Abgelaufen',
                            style: tt.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            post.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.15,
                            ),
                          ),
                          if (post.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              post.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                color:
                                    Colors.white.withValues(alpha: 0.87),
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Ruhige Meta-Zeile
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Row(
                    children: [
                      if (entry.avgRating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 18, color: AppColors.googleYellow),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.avgRating!.toStringAsFixed(1)} (${entry.ratingCount})',
                          style: tt.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ] else
                        Text('Neu',
                            style: tt.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      if (post.likesCount > 0) ...[
                        const SizedBox(width: 14),
                        Icon(Icons.favorite_rounded,
                            size: 15, color: cs.primary),
                        const SizedBox(width: 4),
                        Text('${post.likesCount}',
                            style: tt.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant, size: 22),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

String _feedTypeLabel(String type) {
  const labels = {
    'offer': 'Angebot',
    'onePlusOneFree': '1+1 Gratis',
    'buyOneGetOneFree': 'Kauf 1, bekomme 1',
    'twoPlusOneFree': '2+1 Gratis',
    'buyTwoGetOneFree': 'Kauf 2, bekomme 1',
    'categoryDiscountPercent': 'Prozent-Rabatt',
    'categoryDiscountFixed': 'Rabatt',
    'happyHour': 'Happy Hour',
    'quickSell': 'Schnell weg',
    'rescueMe': 'Rette mich',
    'news': 'Neuigkeit',
    'newProduct': 'Neue Ware',
    'info': 'Info',
    'communityEvent': 'Event',
    'hiring': 'Team gesucht',
    'sponsoredSpot': 'Sponsored',
  };
  return labels[type] ?? type;
}

// ── Swipe-Mini-Cards ─────────────────────────────────────────────────────────

class _SwipeCardData {
  const _SwipeCardData(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SwipeCardsRow extends StatelessWidget {
  const _SwipeCardsRow({required this.cards});

  final List<_SwipeCardData> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _SwipeCard(data: cards[i]),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({required this.data});

  final _SwipeCardData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: data.onTap,
        child: Ink(
          width: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(data.icon,
                    size: 21, color: cs.onSecondaryContainer),
              ),
              const SizedBox(height: 7),
              Text(
                data.label,
                style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Süßes zentriertes Popout ─────────────────────────────────────────────────

void showPartnerPopout(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget child,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _PartnerPopout(icon: icon, title: title, child: child),
  );
}

class _PartnerPopout extends StatelessWidget {
  const _PartnerPopout({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: cs.onSecondaryContainer, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            child,
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopoutColumn extends StatelessWidget {
  const _PopoutColumn({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
}

class _PopoutText extends StatelessWidget {
  const _PopoutText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
    );
  }
}

class _HoursList extends StatelessWidget {
  const _HoursList({required this.hours});

  final Map<String, dynamic> hours;

  static const _days = [
    ('monday', 'Montag'),
    ('tuesday', 'Dienstag'),
    ('wednesday', 'Mittwoch'),
    ('thursday', 'Donnerstag'),
    ('friday', 'Freitag'),
    ('saturday', 'Samstag'),
    ('sunday', 'Sonntag'),
  ];

  String _format(dynamic value) {
    if (value is Map) {
      if (value['closed'] == true) return 'Geschlossen';
      final open = value['open']?.toString();
      final close = value['close']?.toString();
      if (open != null && close != null) return '$open – $close';
      final slots = value['slots'];
      if (slots is List && slots.isNotEmpty) {
        return slots
            .whereType<Map>()
            .map((s) => '${s['open']} – ${s['close']}')
            .join(', ');
      }
    }
    return 'Geschlossen';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final todayIdx = DateTime.now().weekday - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _days.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Text(
                  _days[i].$2,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight:
                        i == todayIdx ? FontWeight.w700 : FontWeight.w500,
                    color: i == todayIdx ? cs.primary : cs.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  _format(hours[_days[i].$1]),
                  style: tt.bodyMedium?.copyWith(
                    color: i == todayIdx ? cs.primary : cs.onSurfaceVariant,
                    fontWeight:
                        i == todayIdx ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Primäraktion: Wallet ─────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (isChecking) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (isInWallet) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: cs.onSecondaryContainer, size: 20),
            const SizedBox(width: 8),
            Text(
              'Du folgst',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isAdding ? null : onAdd,
        icon: isAdding
            ? const SizedBox.shrink()
            : const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: isAdding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('Folgen'),
      ),
    );
  }
}
