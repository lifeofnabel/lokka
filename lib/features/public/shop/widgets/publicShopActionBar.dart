import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../providers/publicShopProvider.dart';

class PublicShopActionBar extends StatelessWidget {
  const PublicShopActionBar({
    super.key,
    required this.provider,
    required this.darkMode,
    required this.onOrder,
  });

  final PublicShopProvider provider;
  final bool darkMode;
  final Future<bool> Function() onOrder;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final itemCount = provider.cart.fold<int>(0, (sum, item) => sum + item.quantity);
    final bg = darkMode ? const Color(0xFFF8FAF5) : const Color(0xFF171A18);
    final fg = darkMode ? const Color(0xFF171A18) : const Color(0xFFF8FAF5);
    final muted = darkMode ? const Color(0xFF70766F) : const Color(0xFFB7BEB6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        elevation: 0,
        child: InkWell(
          onTap: provider.createdOrderId == null
              ? () => _openCartSheet(context, darkMode: darkMode, onOrder: onOrder)
              : null,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: provider.createdOrderId != null
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: fg, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          texts.text('public.shop.orderSent'),
                          style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.shopping_bag_rounded, color: fg),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              itemCount == 0
                                  ? texts.text('public.shop.cart')
                                  : texts.text('public.shop.orderWithCount').replaceAll('{count}', itemCount.toString()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              provider.cart.isEmpty
                                  ? texts.text('public.shop.cartEmpty')
                                  : _price(provider.totalPrice, texts),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_up_rounded, color: fg),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

void _openCartSheet(
  BuildContext context, {
  required bool darkMode,
  required Future<bool> Function() onOrder,
}) {
  final bg = darkMode ? const Color(0xFF1A1B18) : const Color(0xFFFFFEFB);
  final ink = darkMode ? const Color(0xFFF8FAF5) : const Color(0xFF171A18);
  final muted = darkMode ? const Color(0xFFB7BEB6) : const Color(0xFF70766F);
  final soft = darkMode ? const Color(0xFF262824) : const Color(0xFFEDEAE1);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Consumer<PublicShopProvider>(
      builder: (context, provider, _) {
        final texts = context.watch<LanguageService>();
        final itemCount = provider.cart.fold<int>(0, (sum, item) => sum + item.quantity);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        texts.text('public.shop.cart'),
                        style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: provider.cart.isEmpty
                          ? null
                          : () {
                              for (final entry in [...provider.cart]) {
                                while (provider.cart.any((item) => item.item.id == entry.item.id)) {
                                  provider.removeItem(entry.item.id);
                                }
                              }
                            },
                      child: Text(texts.text('public.shop.clear')),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (provider.cart.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      texts.text('public.shop.cartEmpty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.44,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: provider.cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = provider.cart[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: ink,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '${entry.quantity}x',
                                  style: TextStyle(color: bg, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                                ),
                              ),
                              Text(
                                _price(entry.total, texts),
                                style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                              ),
                              IconButton(
                                onPressed: () => provider.removeItem(entry.item.id),
                                icon: Icon(Icons.remove_circle_outline_rounded, color: muted),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: provider.cart.isEmpty || provider.isSaving
                      ? null
                      : () async {
                          final ok = await onOrder();
                          if (ok && context.mounted) Navigator.of(context).pop();
                        },
                  icon: provider.isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: bg),
                        )
                      : const Icon(Icons.receipt_long_rounded),
                  label: Text(
                    itemCount == 0
                        ? texts.text('public.shop.order')
                        : texts.text('public.shop.orderWithCount').replaceAll('{count}', itemCount.toString()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: bg,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
