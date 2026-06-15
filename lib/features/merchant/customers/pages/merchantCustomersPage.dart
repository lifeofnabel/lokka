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
      child: provider.isLoading
          ? const MerchantLoadingCards(count: 5)
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterChips(provider: provider),
                    const SizedBox(height: AppSpacing.md),
                    if (provider.visibleCustomers.isEmpty)
                      MerchantEmptyState(
                        title: texts.text('merchant.customers.emptyTitle'),
                        message: texts.text('merchant.customers.emptyMessage'),
                        actionLabel: texts.text('common.refresh'),
                        onAction: provider.load,
                      )
                    else
                      ...provider.visibleCustomers.map(
                        (customer) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CustomerCard(customer: customer),
                        ),
                      ),
                  ],
                ),
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
        selectedColor: MerchantPremiumColors.ink,
        backgroundColor: MerchantPremiumColors.surface,
        side: const BorderSide(color: MerchantPremiumColors.line),
        labelStyle: TextStyle(
          color: selected ? Colors.white : MerchantPremiumColors.ink,
          fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${texts.text('merchant.customers.lastVisit')}: ${_dateLabel(context, customer.lastVisitAt)}',
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          fontSize: 11,
          fontWeight: FontWeight.w900,
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

String _dateLabel(BuildContext context, DateTime? value) {
  if (value == null) return context.read<LanguageService>().text('common.none');
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'L';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length < 2 ? parts.first.length : 2).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
