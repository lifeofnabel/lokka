import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/core/widgets/appSearchField.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/partners/providers/userPartnersProvider.dart';
import 'package:lokka/features/user/partners/widgets/partnerCard.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';
import 'package:lokka/features/user/reviews/models/merchantRating.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

// Frankfurt fallback coordinates
const _kFallbackLat = 50.1109;
const _kFallbackLng = 8.6821;

const _kRadiusOptions = <double>[1, 3, 5, 10, 25];

class UserPartnersPage extends StatefulWidget {
  const UserPartnersPage({super.key});

  @override
  State<UserPartnersPage> createState() => _UserPartnersPageState();
}

class _UserPartnersPageState extends State<UserPartnersPage> {
  late final UserWalletService _walletService;
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _walletService = context.read<UserWalletProvider>().service;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid != null) {
      await context.read<UserPartnersProvider>().loadExtras(uid);
    }
  }

  Future<void> _requestLocation() async {
    setState(() => _locationLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          context.read<UserPartnersProvider>()
              .updateLocation(_kFallbackLat, _kFallbackLng);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        context.read<UserPartnersProvider>()
            .updateLocation(pos.latitude, pos.longitude);
      }
    } catch (_) {
      if (mounted) {
        context.read<UserPartnersProvider>()
            .updateLocation(_kFallbackLat, _kFallbackLng);
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _toggleWallet(PublicMerchantUserModel merchant) async {
    final provider = context.read<UserPartnersProvider>();
    final inWallet = provider.walletIds.contains(merchant.merchantId);
    if (inWallet) return; // only add, not remove from this screen
    try {
      await _walletService.addToWallet(merchant);
      if (mounted) provider.addWalletId(merchant.merchantId);
    } catch (_) {}
  }

  void _openDetail(PublicMerchantUserModel merchant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPartnerDetailPage(merchant: merchant),
      ),
    );
  }

  void _showFilterSheet(UserPartnersProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _FilterSheet(
        provider: provider,
        onApply: (area, category, radius, walletOnly) {
          provider.setFilter(
            area: area,
            category: category,
            radiusKm: radius,
            walletOnly: walletOnly,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserPartnersProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const AppLoadingState();
        }
        if (provider.error != null) {
          return AppErrorState(
            message: 'Partner konnten nicht geladen werden',
            onRetry: () => context.read<UserPartnersProvider>().retry(),
          );
        }

        final filtered = provider.filteredPartners;

        return CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                totalCount: provider.totalCount,
                filteredCount: filtered.length,
                hasFilters: provider.hasActiveFilters,
                searchQuery: provider.searchQuery,
                userLat: provider.userLat,
                locationLoading: _locationLoading,
                onSearch: provider.setSearch,
                onLocationTap: _requestLocation,
                onFilterTap: () => _showFilterSheet(provider),
                onClearFilters: provider.clearFilters,
              ),
            ),
            // ── Active filter chips ──────────────────────────────────────
            if (provider.hasActiveFilters)
              SliverToBoxAdapter(
                child: _ActiveFilters(
                  provider: provider,
                  onClear: provider.clearFilters,
                ),
              ),
            // ── Empty state (SliverFillRemaining must be last) ───────────
            if (filtered.isEmpty) ...[
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.store_outlined,
                  title: 'Keine Partner gefunden',
                  message: 'Ändere deine Filter oder schau später nochmal.',
                ),
              ),
            ] else ...[
              // ── Beliebt row ──────────────────────────────────────────
              if (provider.beliebtPartners.isNotEmpty) ...[
                _sectionHeader('Beliebt'),
                SliverToBoxAdapter(
                  child: _HorizontalRow(
                    merchants: provider.beliebtPartners,
                    walletIds: provider.walletIds,
                    onTap: _openDetail,
                    onWalletTap: _toggleWallet,
                    ratingFor: provider.ratingFor,
                  ),
                ),
              ],
              // ── Neu dabei row ────────────────────────────────────────
              if (provider.newPartners.isNotEmpty) ...[
                _sectionHeader('Neu dabei'),
                SliverToBoxAdapter(
                  child: _HorizontalRow(
                    merchants: provider.newPartners,
                    walletIds: provider.walletIds,
                    onTap: _openDetail,
                    onWalletTap: _toggleWallet,
                    ratingFor: provider.ratingFor,
                  ),
                ),
              ],
              // ── Category rows ────────────────────────────────────────
              for (final entry in provider.partnersByCategory.entries) ...[
                _sectionHeader(entry.key),
                SliverToBoxAdapter(
                  child: _HorizontalRow(
                    merchants: entry.value,
                    walletIds: provider.walletIds,
                    onTap: _openDetail,
                    onWalletTap: _toggleWallet,
                    ratingFor: provider.ratingFor,
                  ),
                ),
              ],
              // bottom padding so last card clears the nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) {
          final tt = Theme.of(context).textTheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
            child: Text(
              title,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
  const _Header({
    required this.totalCount,
    required this.filteredCount,
    required this.hasFilters,
    required this.searchQuery,
    required this.userLat,
    required this.locationLoading,
    required this.onSearch,
    required this.onLocationTap,
    required this.onFilterTap,
    required this.onClearFilters,
  });

  final int totalCount;
  final int filteredCount;
  final bool hasFilters;
  final String searchQuery;
  final double? userLat;
  final bool locationLoading;
  final ValueChanged<String> onSearch;
  final VoidCallback onLocationTap;
  final VoidCallback onFilterTap;
  final VoidCallback onClearFilters;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(_Header old) {
    super.didUpdateWidget(old);
    if (old.searchQuery != widget.searchQuery &&
        _ctrl.text != widget.searchQuery) {
      _ctrl.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: AppColors.surfaceBg,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partner',
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.hasFilters
                          ? '${widget.filteredCount} von ${widget.totalCount}'
                          : '${widget.totalCount} Partner in deiner Nähe',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Location chip
              _LocationButton(
                active: widget.userLat != null,
                loading: widget.locationLoading,
                onTap: widget.locationLoading ? null : widget.onLocationTap,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Search + filter row
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _ctrl,
                  hintText: 'Shop suchen…',
                  onChanged: widget.onSearch,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Filter button
              IconButton(
                onPressed: widget.onFilterTap,
                icon: const Icon(Icons.tune_rounded),
                style: IconButton.styleFrom(
                  backgroundColor:
                      widget.hasFilters ? cs.primary : AppColors.surfaceGray,
                  foregroundColor:
                      widget.hasFilters ? cs.onPrimary : cs.onSurfaceVariant,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final bool active;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = active ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Material(
      color: active ? cs.secondaryContainer : AppColors.surfaceGray,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me_rounded, size: 15, color: fg),
                    const SizedBox(width: 5),
                    Text(
                      active ? 'Aktiv' : 'Standort',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Active filter chips ───────────────────────────────────────────────────────

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.provider, required this.onClear});

  final UserPartnersProvider provider;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];
    if (provider.selectedArea != null) chips.add(provider.selectedArea!);
    if (provider.selectedCategory != null) chips.add(provider.selectedCategory!);
    if (provider.radiusKm != null) chips.add('${provider.radiusKm!.toInt()} km');
    if (provider.walletOnly) chips.add('Meine Wallet');

    if (chips.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips.map((c) => Chip(
                label: Text(c),
                backgroundColor: cs.secondaryContainer,
                side: BorderSide.none,
                labelStyle: TextStyle(color: cs.onSecondaryContainer),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )),
          TextButton(
            onPressed: onClear,
            child: const Text('Alle löschen'),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal row ────────────────────────────────────────────────────────────

class _HorizontalRow extends StatelessWidget {
  const _HorizontalRow({
    required this.merchants,
    required this.walletIds,
    required this.onTap,
    required this.onWalletTap,
    required this.ratingFor,
  });

  final List<PublicMerchantUserModel> merchants;
  final Set<String> walletIds;
  final void Function(PublicMerchantUserModel) onTap;
  final void Function(PublicMerchantUserModel) onWalletTap;
  final MerchantRating? Function(String) ratingFor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 256,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: merchants.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          final m = merchants[i];
          return PartnerHorizontalCard(
            merchant: m,
            inWallet: walletIds.contains(m.merchantId),
            rating: ratingFor(m.merchantId),
            onTap: () => onTap(m),
            onWalletTap: () => onWalletTap(m),
          );
        },
      ),
    );
  }
}

// ── Filter BottomSheet ────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.provider, required this.onApply});

  final UserPartnersProvider provider;
  final void Function(
      String? area,
      String? category,
      double? radiusKm,
      bool walletOnly) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _area;
  late String? _category;
  late double? _radiusKm;
  late bool _walletOnly;

  @override
  void initState() {
    super.initState();
    _area = widget.provider.selectedArea;
    _category = widget.provider.selectedCategory;
    _radiusKm = widget.provider.radiusKm;
    _walletOnly = widget.provider.walletOnly;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              // Handle + title
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter',
                            style: tt.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _area = null;
                            _category = null;
                            _radiusKm = null;
                            _walletOnly = false;
                          }),
                          child: const Text('Zurücksetzen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Wallet-only toggle
                    Material(
                      color: AppColors.surfaceGray,
                      borderRadius: BorderRadius.circular(16),
                      child: SwitchListTile(
                        value: _walletOnly,
                        onChanged: (v) => setState(() => _walletOnly = v),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Nur meine Wallet',
                          style: tt.titleMedium,
                        ),
                        subtitle: Text(
                          'Partner in deiner Wallet anzeigen',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Radius
                    _FilterSection(
                      title: 'Radius',
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          _FilterChip(
                            label: 'Egal',
                            selected: _radiusKm == null,
                            onTap: () => setState(() => _radiusKm = null),
                          ),
                          ..._kRadiusOptions.map((r) => _FilterChip(
                                label: '${r.toInt()} km',
                                selected: _radiusKm == r,
                                onTap: () => setState(() => _radiusKm = r),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Category
                    if (widget.provider.availableCategories.isNotEmpty) ...[
                      _FilterSection(
                        title: 'Kategorie',
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _FilterChip(
                              label: 'Alle',
                              selected: _category == null,
                              onTap: () => setState(() => _category = null),
                            ),
                            ...widget.provider.availableCategories
                                .map((c) => _FilterChip(
                                      label: c,
                                      selected: _category == c,
                                      onTap: () =>
                                          setState(() => _category = c),
                                    )),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    // Area
                    if (widget.provider.availableAreas.isNotEmpty) ...[
                      _FilterSection(
                        title: 'Gebiet',
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _FilterChip(
                              label: 'Alle',
                              selected: _area == null,
                              onTap: () => setState(() => _area = null),
                            ),
                            ...widget.provider.availableAreas
                                .map((a) => _FilterChip(
                                      label: a,
                                      selected: _area == a,
                                      onTap: () => setState(() => _area = a),
                                    )),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
              // Apply button
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg +
                      MediaQuery.of(context).viewPadding.bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () =>
                        widget.onApply(_area, _category, _radiusKm, _walletOnly),
                    child: const Text('Filter anwenden'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

