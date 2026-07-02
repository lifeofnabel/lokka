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

/// Follower-Seite: wer dem Laden folgt, neueste zuerst, mit Namens-Suche.
/// Die früheren Programm-Filter-Chips (Stempel/Punkte/Coupons/Bestellungen)
/// waren tote Filter (usedSystems trägt nur 'follower') und sind entfernt.
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
      // Slivers statt Column-Spread: Follower-Karten werden via SliverList.builder
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
                      child: _FollowerHeader(provider: provider),
                    ),
                  ),
                  if (provider.visibleCustomers.isEmpty)
                    SliverToBoxAdapter(
                      child: MerchantEmptyState(
                        title: texts.text(provider.search.trim().isEmpty
                            ? 'merchant.customers.emptyTitle'
                            : 'merchant.customers.searchEmptyTitle'),
                        message: texts.text(provider.search.trim().isEmpty
                            ? 'merchant.customers.emptyMessage'
                            : 'merchant.customers.searchEmptyMessage'),
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

/// Kopfbereich der Liste: Follower-Zähler + Namens-Suche (ersetzt die
/// frühere Filter-Chip-Leiste).
class _FollowerHeader extends StatelessWidget {
  const _FollowerHeader({required this.provider});

  final MerchantCustomersProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final count = provider.followerCount;
    final label = count == 1
        ? texts.text('merchant.customers.countOne')
        : texts.text('merchant.customers.countMany').replaceAll('{count}', '$count');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        // Suche lohnt erst ab einer Handvoll Followern – vorher wäre das Feld
        // nur Rauschen über einer 2-Zeilen-Liste.
        if (count > 5) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            onChanged: provider.setSearch,
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: texts.text('merchant.customers.searchHint'),
              hintStyle: TextStyle(
                color: MerchantPremiumColors.muted.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: MerchantPremiumColors.muted),
              filled: true,
              fillColor: MerchantPremiumColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: MerchantPremiumColors.gold, width: 1.4),
              ),
            ),
          ),
        ],
      ],
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
    final subtitle = customer.followedAt != null
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
                      const SizedBox(height: 6),
                      _FollowPill(label: texts.text('merchant.customers.follows')),
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
            // Interessen nur zeigen, wenn der Follower welche geteilt hat –
            // keine leeren „keine Angaben"-Sektionen im Sheet.
            if (customer.interests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                label: texts.text('merchant.customers.interests'),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: customer.interests
                      .map((interest) => _InterestPill(label: interest))
                      .toList(),
                ),
              ),
            ],
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

/// „Folgt dir"-Pille (Gold-Akzent).
class _FollowPill extends StatelessWidget {
  const _FollowPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.goldSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.gold),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Neutrale Interessen-Pille.
class _InterestPill extends StatelessWidget {
  const _InterestPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
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
