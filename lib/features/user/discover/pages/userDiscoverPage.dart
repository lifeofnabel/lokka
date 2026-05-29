import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/discover/providers/userDiscoverProvider.dart';
import 'package:lokka/features/user/discover/widgets/discoverCard.dart';
import 'package:lokka/features/user/discover/widgets/discoverSection.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';

const _shopTypes = ['Food', 'Café', 'Kiosk', 'Beauty', 'Fitness', 'Bakery', 'Drinks'];

class UserDiscoverPage extends StatelessWidget {
  const UserDiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDiscoverProvider>(
      builder: (context, provider, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            expandedHeight: 60,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Entdecken',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: _SearchHint(),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: _FilterChips(
                selected: provider.selectedShopType,
                onSelected: provider.setShopType,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverToBoxAdapter(
            child: _MapSection(
              merchants: provider.merchants
                  .where((m) => m.hasCoordinates)
                  .toList(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          if (provider.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (provider.error != null)
            const SliverToBoxAdapter(child: _ErrorView())
          else if (provider.merchants.isEmpty)
            const SliverToBoxAdapter(child: _EmptyDiscoverView())
          else ...[
            SliverToBoxAdapter(
              child: DiscoverSection(
                title: 'In deiner Nähe',
                child: SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: provider.merchants.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (ctx, i) => DiscoverCard(
                      merchant: provider.merchants[i],
                      onTap: () => _openDetail(ctx, provider.merchants[i]),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: provider.merchants.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, i) {
                  final m = provider.merchants[i];
                  return _MerchantListTile(
                    merchant: m,
                    onTap: () => _openDetail(ctx, m),
                  );
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, PublicMerchantUserModel merchant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPartnerDetailPage(merchant: merchant),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.gray300, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Shops durchsuchen…',
            style: TextStyle(fontSize: 14, color: AppColors.gray300),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = [null, ..._shopTypes];
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final value = options[i];
        final label = value ?? 'Alle';
        final isActive = value == selected;
        return GestureDetector(
          onTap: () => onSelected(isActive ? null : value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.black : AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? AppColors.black : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.white : AppColors.gray700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.merchants});

  final List<PublicMerchantUserModel> merchants;

  LatLng get _center {
    if (merchants.isEmpty) return const LatLng(52.52, 13.405);
    final avgLat = merchants.map((m) => m.lat!).reduce((a, b) => a + b) / merchants.length;
    final avgLng = merchants.map((m) => m.lng!).reduce((a, b) => a + b) / merchants.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: _center,
          initialZoom: merchants.isEmpty ? 12 : 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.lokka.app',
          ),
          if (merchants.isNotEmpty)
            MarkerLayer(
              markers: merchants
                  .map(
                    (m) => Marker(
                      point: LatLng(m.lat!, m.lng!),
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.mintStrong,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.store_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MerchantListTile extends StatelessWidget {
  const _MerchantListTile({required this.merchant, required this.onTap});

  final PublicMerchantUserModel merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.mintSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: AppColors.mintStrong,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.shopName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [merchant.shopType, merchant.area]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.gray300),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiscoverView extends StatelessWidget {
  const _EmptyDiscoverView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.explore_off_rounded, size: 56, color: AppColors.gray300),
          SizedBox(height: AppSpacing.md),
          Text(
            'Noch keine Shops verfügbar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            'Neue Partner kommen bald.',
            style: TextStyle(fontSize: 13, color: AppColors.gray300),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.gray300),
          SizedBox(height: AppSpacing.md),
          Text(
            'Laden fehlgeschlagen',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }
}
