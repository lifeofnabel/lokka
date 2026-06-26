import 'package:flutter/material.dart';

import '../../../../core/services/languageService.dart';
import '../../shared/widgets/merchantPremiumUi.dart';

/// EINE Quelle der Wahrheit für die Darstellung eines Bestell-Status
/// (Farbe + Label). Vorher war diese Logik in `orderCard`, `orderDetailPanel`
/// und der Tisch-Einsicht dupliziert – jede Kopie konnte driften. Alle Order-
/// Oberflächen nutzen jetzt diese Helfer + [OrderStatusPill].
class OrderStatusStyle {
  const OrderStatusStyle._();

  /// Akzentfarbe je Status (Merchant-Dark-Tokens).
  static Color colorOf(String status) {
    return switch (status) {
      'preparing' => MerchantPremiumColors.gold,
      'done' => MerchantPremiumColors.success,
      'cancelled' => MerchantPremiumColors.danger,
      _ => MerchantPremiumColors.warning, // 'new' (+ Fallback)
    };
  }

  /// Lokalisiertes Label je Status.
  static String labelOf(LanguageService texts, String status) {
    return switch (status) {
      'preparing' => texts.text('merchant.orders.status.preparing'),
      'done' => texts.text('merchant.orders.status.done'),
      'cancelled' => texts.text('merchant.orders.status.cancelled'),
      _ => texts.text('merchant.orders.status.new'),
    };
  }
}

/// Einheitliche Status-/Zustands-Pille (Label + Akzentfarbe), geteilt von der
/// Bestell-Karte und der Tisch-Einsicht (Offen/Beendet). Tönt Hintergrund +
/// Rand in der Akzentfarbe.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.label, required this.color});

  /// Komfort-Konstruktor direkt aus einem Bestell-Status.
  factory OrderStatusPill.forStatus(LanguageService texts, String status,
      {Key? key}) {
    return OrderStatusPill(
      key: key,
      label: OrderStatusStyle.labelOf(texts, status),
      color: OrderStatusStyle.colorOf(status),
    );
  }

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
