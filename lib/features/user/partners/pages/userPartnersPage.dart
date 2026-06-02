import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/partners/providers/userPartnersProvider.dart';
import 'package:lokka/features/user/partners/widgets/partnerCard.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';
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
    _walletService = UserWalletService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
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
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null) {
          return _ErrorView(
            error: provider.error,
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
                child: _EmptyView(),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
            letterSpacing: -0.3,
          ),
        ),
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
    return Container(
      color: AppColors.background,
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
                    const Text(
                      'Partner',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      widget.hasFilters
                          ? '${widget.filteredCount} von ${widget.totalCount}'
                          : '${widget.totalCount} Partner in deiner Nähe',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              // Location button
              GestureDetector(
                onTap: widget.locationLoading ? null : widget.onLocationTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.userLat != null
                        ? AppColors.mintSoft
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: widget.userLat != null
                          ? AppColors.mintStrong
                          : AppColors.border,
                    ),
                  ),
                  child: widget.locationLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.mintStrong,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.near_me_rounded,
                              size: 15,
                              color: widget.userLat != null
                                  ? AppColors.mintStrong
                                  : AppColors.gray500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.userLat != null ? 'Aktiv' : 'Standort',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.userLat != null
                                    ? AppColors.mintStrong
                                    : AppColors.gray500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Search + filter row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: widget.onSearch,
                  style: const TextStyle(fontSize: 14, color: AppColors.black),
                  decoration: InputDecoration(
                    hintText: 'Shop suchen…',
                    hintStyle: const TextStyle(
                        color: AppColors.gray300, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.gray300, size: 20),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _ctrl.clear();
                              widget.onSearch('');
                            },
                            child: const Icon(Icons.clear_rounded,
                                color: AppColors.gray300, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide:
                          const BorderSide(color: AppColors.black),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Filter button
              GestureDetector(
                onTap: widget.onFilterTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.hasFilters
                        ? AppColors.mintStrong
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: widget.hasFilters
                          ? AppColors.mintStrong
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: widget.hasFilters ? Colors.white : AppColors.gray700,
                  ),
                ),
              ),
            ],
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        children: [
          ...chips.map((c) => Chip(
                label: Text(c,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mintStrong,
                        fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.mintSoft,
                side: const BorderSide(color: AppColors.mintStrong),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Alle löschen',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w600),
              ),
            ),
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
  });

  final List<PublicMerchantUserModel> merchants;
  final Set<String> walletIds;
  final void Function(PublicMerchantUserModel) onTap;
  final void Function(PublicMerchantUserModel) onWalletTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: merchants.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final m = merchants[i];
          return PartnerHorizontalCard(
            merchant: m,
            inWallet: walletIds.contains(m.merchantId),
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
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
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
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _area = null;
                            _category = null;
                            _radiusKm = null;
                            _walletOnly = false;
                          }),
                          child: const Text(
                            'Zurücksetzen',
                            style: TextStyle(color: AppColors.mintStrong),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Wallet-only toggle
                    _FilterSection(
                      title: 'Meine Wallet',
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _walletOnly = !_walletOnly),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 26,
                              decoration: BoxDecoration(
                                color: _walletOnly
                                    ? AppColors.mintStrong
                                    : AppColors.gray300,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 200),
                                alignment: _walletOnly
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Nur Partner in meiner Wallet',
                              style: TextStyle(
                                fontSize: 14,
                                color: _walletOnly
                                    ? AppColors.black
                                    : AppColors.gray500,
                                fontWeight: _walletOnly
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
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
                  child: FilledButton(
                    onPressed: () =>
                        widget.onApply(_area, _category, _radiusKm, _walletOnly),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mintStrong,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Filter anwenden',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.gray700,
            letterSpacing: 0.3,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintStrong : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.mintStrong : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.store_outlined, size: 64, color: AppColors.gray300),
        SizedBox(height: AppSpacing.md),
        Text(
          'Keine Partner gefunden',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.gray500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Ändere deine Filter oder schau später nochmal.',
          style: TextStyle(fontSize: 14, color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.gray300),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Partner konnten nicht geladen werden',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray500,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Erneut versuchen'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mintStrong,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
