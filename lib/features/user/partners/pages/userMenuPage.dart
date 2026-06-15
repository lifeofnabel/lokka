import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/partners/models/userMenuModels.dart';
import 'package:lokka/features/user/partners/services/userMenuService.dart';

/// Vollbild-Speisekarte eines Partners (integrierte Lokka-Karte, read-only).
class UserMenuPage extends StatefulWidget {
  const UserMenuPage({
    super.key,
    required this.merchantId,
    required this.shopName,
    this.tablesEnabled = false,
  });

  final String merchantId;
  final String shopName;

  /// „Tisch wählen"-Stub einblenden (nur wenn der Merchant Tische pflegt).
  final bool tablesEnabled;

  @override
  State<UserMenuPage> createState() => _UserMenuPageState();
}

class _UserMenuPageState extends State<UserMenuPage> {
  late final UserMenuService _service;
  List<UserMenuCategory> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = UserMenuService(
      firestoreService: context.read<FirestoreService>(),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await _service.fetchMenu(widget.merchantId);
      if (mounted) {
        setState(() {
          _categories = cats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.greenTint,
      body: CustomScrollView(
        slivers: [
          _header(),
          if (_loading)
            const SliverFillRemaining(
                hasScrollBody: false, child: AppLoadingState())
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(
                  message: 'Speisekarte konnte nicht geladen werden',
                  onRetry: _load),
            )
          else if (_categories.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.restaurant_menu_rounded,
                title: 'Noch keine Speisekarte',
                message: 'Dieser Partner hat noch keine Einträge veröffentlicht.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
              sliver: SliverList.builder(
                itemCount: _categories.length,
                itemBuilder: (_, i) => _CategorySection(category: _categories[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.mintGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speisekarte',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          Text(
                            widget.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.tablesEnabled && !_loading && _error == null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _TableSelectButton(
                    onTap: () => _showTableStub(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showTableStub(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.event_seat_rounded,
                    color: cs.onSecondaryContainer, size: 32),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tisch wählen',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tischauswahl direkt aus der Speisekarte kommt in Kürze. '
                'Bald kannst du hier deinen Tisch reservieren.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      );
    },
  );
}

class _TableSelectButton extends StatelessWidget {
  const _TableSelectButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.event_seat_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Tisch wählen',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});
  final UserMenuCategory category;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.sm),
          child: Row(
            children: [
              if (category.emoji != null) ...[
                Text(category.emoji!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Text(
                category.name,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        ...category.items.map((item) => _MenuItemCard(item: item)),
      ],
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});
  final UserMenuItem item;

  String _price(num value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: SizedBox(
                width: 68,
                height: 68,
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: cs.secondaryContainer),
                  errorWidget: (_, __, ___) => Container(
                    color: cs.secondaryContainer,
                    child: Icon(Icons.restaurant_rounded,
                        color: cs.onSecondaryContainer, size: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      height: 1.35,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _price(item.price),
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              if (item.hasDiscount)
                Text(
                  _price(item.originalPrice!),
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
