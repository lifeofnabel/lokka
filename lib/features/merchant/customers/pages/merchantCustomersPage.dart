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
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
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
                // 'Letzter Besuch' nur zeigen, wenn ein Datum existiert – sonst
                // klebte ein 'Keine'/'none' an der Zeile.
                if (customer.lastVisitAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${texts.text('merchant.customers.lastVisit')}: ${_formatDate(texts, customer.lastVisitAt!)}',
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
                  children: customer.usedSystems.isEmpty
                      ? [_SystemPill(label: texts.text('merchant.customers.noSystem'))]
                      : customer.usedSystems.map((system) => _SystemPill(label: _systemLabel(texts, system))).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemPill extends StatelessWidget {
  const _SystemPill({required this.label});

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
