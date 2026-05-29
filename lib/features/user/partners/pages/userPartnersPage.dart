import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/partners/providers/userPartnersProvider.dart';
import 'package:lokka/features/user/partners/widgets/partnerCard.dart';
import 'package:lokka/features/user/partners/widgets/partnerFilterBar.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';

class UserPartnersPage extends StatelessWidget {
  const UserPartnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserPartnersProvider>(
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
                'Partner',
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: _SearchField(
                value: provider.searchQuery,
                onChanged: provider.setSearch,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverToBoxAdapter(
            child: PartnerFilterBar(
              options: provider.availableShopTypes,
              selected: provider.selectedShopType,
              onSelected: (v) => provider.setFilter(shopType: v),
            ),
          ),
          if (provider.availableAreas.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: PartnerFilterBar(
                  options: provider.availableAreas,
                  selected: provider.selectedArea,
                  onSelected: (v) => provider.setFilter(area: v),
                  label: 'Alle Gebiete',
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.error != null)
            const SliverFillRemaining(child: _PartnersErrorView())
          else if (provider.partners.isEmpty)
            const SliverFillRemaining(child: _PartnersEmptyView())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: provider.partners.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, i) {
                  final m = provider.partners[i];
                  return PartnerCard(
                    merchant: m,
                    onTap: () => _openDetail(ctx, m),
                  );
                },
              ),
            ),
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

class _SearchField extends StatefulWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.black),
      decoration: InputDecoration(
        hintText: 'Shop suchen…',
        hintStyle: const TextStyle(color: AppColors.gray300, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray300, size: 20),
        suffixIcon: widget.value.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  widget.onChanged('');
                },
                child: const Icon(Icons.clear_rounded, color: AppColors.gray300, size: 18),
              )
            : null,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
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
          borderSide: const BorderSide(color: AppColors.black),
        ),
      ),
    );
  }
}

class _PartnersEmptyView extends StatelessWidget {
  const _PartnersEmptyView();

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

class _PartnersErrorView extends StatelessWidget {
  const _PartnersErrorView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.gray300),
        SizedBox(height: AppSpacing.md),
        Text(
          'Partner konnten nicht geladen werden',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.gray500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
