import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/merchantCustomerModel.dart';
import '../providers/merchantCustomersProvider.dart';
import '../services/merchantCustomersService.dart';

class MerchantCustomersPage extends StatelessWidget {
  const MerchantCustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantCustomersProvider(
        service: MerchantCustomersService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantCustomersView(),
    );
  }
}

class _MerchantCustomersView extends StatelessWidget {
  const _MerchantCustomersView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantCustomersProvider>();
    final texts = context.watch<LanguageService>();

    return MerchantToolScaffold(
      title: texts.text('merchant.customers.title'),
      subtitle: texts.text('merchant.customers.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.customers.tooltip')),
      // Slivers statt Column-Spread: Kundenkarten werden via SliverList.builder
      // lazy gebaut (Virtualisierung), nicht alle gleichzeitig in den Widgetbaum.
      slivers: provider.isLoading
          ? const [SliverToBoxAdapter(child: MerchantLoadingCards(count: 5))]
          : provider.error != null
              ? [
                  SliverToBoxAdapter(
                    child: MerchantErrorState(
                      message: texts.text(provider.error!),
                      onRetry: provider.load,
                    ),
                  ),
                ]
              : [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _FilterChips(provider: provider),
                    ),
                  ),
                  if (provider.visibleCustomers.isEmpty)
                    SliverToBoxAdapter(
                      child: MerchantEmptyState(
                        title: texts.text('merchant.customers.emptyTitle'),
                        message: texts.text('merchant.customers.emptyMessage'),
                        actionLabel: texts.text('common.refresh'),
                        onAction: provider.load,
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: provider.visibleCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = provider.visibleCustomers[index];
                        return Padding(
                          key: ValueKey(customer.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CustomerCard(customer: customer),
                        );
                      },
                    ),
                ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.provider});

  final MerchantCustomersProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Symmetrisches Rand-Padding: erste/letzte Chip-Kante liegt nicht bündig und
      // beide Seiten zeigen eine kleine Scroll-Affordanz.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          _FilterChip(
            label: texts.text('merchant.customers.filter.all'),
            selected: provider.filter == MerchantCustomerFilter.all,
            onTap: () => provider.setFilter(MerchantCustomerFilter.all),
          ),
          _FilterChip(
            label: texts.text('merchant.customers.filter.followers'),
            selected: provider.filter == MerchantCustomerFilter.followers,
            onTap: () => provider.setFilter(MerchantCustomerFilter.followers),
          ),
          _FilterChip(
            label: texts.text('merchant.customers.filter.stamps'),
            selected: provider.filter == MerchantCustomerFilter.stampCards,
            onTap: () => provider.setFilter(MerchantCustomerFilter.stampCards),
          ),
          _FilterChip(
            label: texts.text('merchant.customers.filter.points'),
            selected: provider.filter == MerchantCustomerFilter.pointsSystems,
            onTap: () => provider.setFilter(MerchantCustomerFilter.pointsSystems),
          ),
          _FilterChip(
            label: texts.text('merchant.customers.filter.coupons'),
            selected: provider.filter == MerchantCustomerFilter.coupons,
            onTap: () => provider.setFilter(MerchantCustomerFilter.coupons),
          ),
          _FilterChip(
            label: texts.text('merchant.customers.filter.orders'),
            selected: provider.filter == MerchantCustomerFilter.orders,
            onTap: () => provider.setFilter(MerchantCustomerFilter.orders),
          ),
          _FilterChip(
            label: texts.text('merchant.customers.filter.lastVisited'),
            selected: provider.filter == MerchantCustomerFilter.lastVisited,
            onTap: () => provider.setFilter(MerchantCustomerFilter.lastVisited),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        // Touch-Target >= 48dp sicherstellen.
        materialTapTargetSize: MaterialTapTargetSize.padded,
        selectedColor: MerchantPremiumColors.ink,
        backgroundColor: MerchantPremiumColors.surface,
        side: const BorderSide(color: MerchantPremiumColors.line),
        labelStyle: TextStyle(
          // Selektiert liegt das Label auf hellem ink-Grund -> dunkles Token statt
          // hartem Colors.white (das war auf hellem Grund praktisch unsichtbar).
          color: selected ? MerchantPremiumColors.surface : MerchantPremiumColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final MerchantCustomerModel customer;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final name = customer.name.trim().isEmpty ? texts.text('merchant.customers.unknownName') : customer.name;
    // Followers show "Folgt dir seit …"; otherwise fall back to last visit.
    final subtitle = customer.isFollower && customer.followedAt != null
        ? '${texts.text('merchant.customers.followsSince')}: ${_formatDate(texts, customer.followedAt!)}'
        : customer.lastVisitAt != null
            ? '${texts.text('merchant.customers.lastVisit')}: ${_formatDate(texts, customer.lastVisitAt!)}'
            : null;
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showCustomerDetail(context, customer),
      child: Row(
        children: [
          _Avatar(name: name, imageUrl: customer.profileImageUrl, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (customer.isFollower)
                      _SystemPill(
                        label: texts.text('merchant.customers.follows'),
                        highlight: true,
                      ),
                    if (customer.usedSystems.isEmpty && !customer.isFollower)
                      _SystemPill(label: texts.text('merchant.customers.noSystem'))
                    else
                      ...customer.usedSystems
                          .map((system) => _SystemPill(label: _systemLabel(texts, system))),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: MerchantPremiumColors.muted),
        ],
      ),
    );
  }
}

/// Round avatar — shows the shared profile image, falling back to initials.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.imageUrl, required this.size});

  final String name;
  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(size * 0.36),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: imageUrl.trim().isEmpty
          ? Center(
              child: Text(
                _initials(name),
                style: TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.32,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 200,
              errorWidget: (context, url, error) => Center(
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.32,
                  ),
                ),
              ),
            ),
    );
  }
}

void _showCustomerDetail(BuildContext context, MerchantCustomerModel customer) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => _CustomerDetailSheet(customer: customer),
  );
}

class _CustomerDetailSheet extends StatelessWidget {
  const _CustomerDetailSheet({required this.customer});

  final MerchantCustomerModel customer;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final name = customer.name.trim().isEmpty
        ? texts.text('merchant.customers.unknownName')
        : customer.name;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Avatar(name: name, imageUrl: customer.profileImageUrl, size: 64),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (customer.isFollower) ...[
                        const SizedBox(height: 6),
                        _SystemPill(
                          label: texts.text('merchant.customers.follows'),
                          highlight: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (customer.followedAt != null)
              _DetailRow(
                icon: Icons.favorite_rounded,
                label: texts.text('merchant.customers.followsSince'),
                value: _formatDate(texts, customer.followedAt!),
              ),
            if (customer.lastVisitAt != null)
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: texts.text('merchant.customers.lastVisit'),
                value: _formatDate(texts, customer.lastVisitAt!),
              ),
            if (customer.postalCode.trim().isNotEmpty)
              _DetailRow(
                icon: Icons.place_rounded,
                label: texts.text('merchant.customers.postalCode'),
                value: customer.postalCode,
              ),
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              label: texts.text('merchant.customers.programs'),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: customer.usedSystems.isEmpty
                    ? [_SystemPill(label: texts.text('merchant.customers.noSystem'))]
                    : customer.usedSystems
                        .map((system) => _SystemPill(label: _systemLabel(texts, system)))
                        .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              label: texts.text('merchant.customers.interests'),
              child: customer.interests.isEmpty
                  ? Text(
                      texts.text('merchant.customers.noInterests'),
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: customer.interests
                          .map((interest) => _SystemPill(label: interest))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: MerchantPremiumColors.muted),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MerchantPremiumColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _SystemPill extends StatelessWidget {
  const _SystemPill({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? MerchantPremiumColors.goldSoft : MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    );
  }
}

String _systemLabel(LanguageService texts, String system) {
  return switch (system) {
    'stampCards' => texts.text('merchant.customers.system.stamps'),
    'pointsSystems' => texts.text('merchant.customers.system.points'),
    'coupons' => texts.text('merchant.customers.system.coupons'),
    'orders' => texts.text('merchant.customers.system.orders'),
    _ => system,
  };
}

// Locale-bewusste, kompakte Datumsausgabe ohne intl-Paket.
String _formatDate(LanguageService texts, DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return switch (texts.localeCode) {
    'en' => '$month/$day/$year',
    _ => '$day.$month.$year', // de/ar: Tag.Monat.Jahr
  };
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'L';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length < 2 ? parts.first.length : 2).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
