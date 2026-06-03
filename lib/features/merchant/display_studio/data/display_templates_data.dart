import 'package:flutter/material.dart';

import '../models/display_layout.dart';
import '../models/display_template.dart';

/// All available templates, grouped by type.
/// IDs follow: {type}_{variant} e.g. 'deal_bigprice'
class DisplayTemplatesData {
  const DisplayTemplatesData._();

  static const List<DisplayTemplate> all = [
    // ── DEAL ─────────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'deal_bigprice',
      type: DisplayLayoutType.deal,
      name: 'Big Price',
      description: 'Großer Preis im Mittelpunkt – maximale Aufmerksamkeit.',
      icon: Icons.local_offer_rounded,
      defaultBlocks: [
        {'type': 'image', 'order': 0, 'isVisible': true, 'value': {'url': '', 'fit': 'cover'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'badge', 'order': 1, 'isVisible': true, 'value': {'text': 'TOP DEAL', 'backgroundColor': '#FF3B30', 'textColor': '#FFFFFF'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 2, 'isVisible': true, 'value': {'content': 'Produktname', 'fontSize': 28.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'price', 'order': 3, 'isVisible': true, 'value': {'price': '', 'oldPrice': '', 'currency': '€', 'color': '#FFFFFF'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'spacer', 'order': 4, 'isVisible': true, 'value': {'height': 16.0}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 5, 'isVisible': true, 'value': {'targetType': 'shop', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Mehr erfahren'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'deal_splitimage',
      type: DisplayLayoutType.deal,
      name: 'Split Image Deal',
      description: 'Bild links, Infos rechts – klar und modern.',
      icon: Icons.view_agenda_rounded,
      defaultBlocks: [
        {'type': 'image', 'order': 0, 'isVisible': true, 'value': {'url': '', 'fit': 'cover'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 1, 'isVisible': true, 'value': {'content': 'Angebot des Tages', 'fontSize': 24.0, 'fontWeight': 'bold', 'color': '#FFFFFF', 'alignment': 'left'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 2, 'isVisible': true, 'value': {'content': 'Nur für kurze Zeit', 'fontSize': 14.0, 'fontWeight': 'normal', 'color': '#CCCCCC', 'alignment': 'left'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'price', 'order': 3, 'isVisible': true, 'value': {'price': '', 'oldPrice': '', 'currency': '€', 'color': '#FFFFFF'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'badge', 'order': 4, 'isVisible': true, 'value': {'text': 'NUR HEUTE', 'backgroundColor': '#FF9500', 'textColor': '#FFFFFF'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── MENU ─────────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'menu_board',
      type: DisplayLayoutType.menu,
      name: 'Menu Board',
      description: 'Klassische digitale Speisekarte für alle Artikel.',
      icon: Icons.menu_book_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Unsere Speisekarte', 'fontSize': 26.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'divider', 'order': 1, 'isVisible': true, 'value': {'color': '#FFFFFF', 'thickness': 1.0, 'opacity': 0.3}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'menuList', 'order': 2, 'isVisible': true, 'value': {'items': [], 'showBorder': true, 'color': '#FFFFFF'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'spacer', 'order': 3, 'isVisible': true, 'value': {'height': 12.0}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 4, 'isVisible': true, 'value': {'targetType': 'menu', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Vollständige Karte'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'menu_categoryfocus',
      type: DisplayLayoutType.menu,
      name: 'Category Focus',
      description: 'Highlight einer Kategorie mit Bild und Auswahl.',
      icon: Icons.category_rounded,
      defaultBlocks: [
        {'type': 'image', 'order': 0, 'isVisible': true, 'value': {'url': '', 'fit': 'cover'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 1, 'isVisible': true, 'value': {'content': 'Kategorie', 'fontSize': 22.0, 'fontWeight': 'bold', 'color': '#FFFFFF', 'alignment': 'left'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'menuList', 'order': 2, 'isVisible': true, 'value': {'items': [], 'showBorder': false, 'color': '#FFFFFF'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── GALLERY ───────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'gallery_soft',
      type: DisplayLayoutType.gallery,
      name: 'Soft Gallery',
      description: 'Sanfte Bildübergänge, ruhig und atmosphärisch.',
      icon: Icons.photo_library_rounded,
      defaultBlocks: [
        {'type': 'gallery', 'order': 0, 'isVisible': true, 'value': {'urls': [], 'durationSeconds': 5, 'effect': 'fade'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 1, 'isVisible': true, 'value': {'content': '', 'fontSize': 18.0, 'fontWeight': 'normal', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'gallery_fullscreen',
      type: DisplayLayoutType.gallery,
      name: 'Fullscreen Loop',
      description: 'Bilder im Vollbildformat – maximale Wirkung.',
      icon: Icons.fullscreen_rounded,
      defaultBlocks: [
        {'type': 'gallery', 'order': 0, 'isVisible': true, 'value': {'urls': [], 'durationSeconds': 4, 'effect': 'slide'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── QR ────────────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'qr_focus',
      type: DisplayLayoutType.qr,
      name: 'QR Focus',
      description: 'Großer QR-Code im Mittelpunkt, klarer CTA.',
      icon: Icons.qr_code_2_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Jetzt scannen', 'fontSize': 26.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 1, 'isVisible': true, 'value': {'targetType': 'shop', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Menü öffnen'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 2, 'isVisible': true, 'value': {'content': 'Oder Link eingeben', 'fontSize': 13.0, 'fontWeight': 'normal', 'color': '#AAAAAA', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'qr_benefit',
      type: DisplayLayoutType.qr,
      name: 'QR + Benefit',
      description: 'QR-Code mit klarem Vorteilstext daneben.',
      icon: Icons.card_giftcard_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Dein Vorteil', 'fontSize': 22.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 1, 'isVisible': true, 'value': {'content': 'Scanne für deinen Vorteil', 'fontSize': 15.0, 'fontWeight': 'normal', 'color': '#DDDDDD', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 2, 'isVisible': true, 'value': {'targetType': 'coupon', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Gutschein sichern'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── LOYALTY ───────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'loyalty_push',
      type: DisplayLayoutType.loyalty,
      name: 'Loyalty Push',
      description: 'Sammelkarte oder Punkte klar kommunizieren.',
      icon: Icons.stars_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Sammle Punkte', 'fontSize': 26.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'loyalty', 'order': 1, 'isVisible': true, 'value': {'title': '', 'description': '', 'rewardText': '', 'showQr': true}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 2, 'isVisible': true, 'value': {'targetType': 'wallet', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Karte öffnen'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'loyalty_reward',
      type: DisplayLayoutType.loyalty,
      name: 'Reward Progress',
      description: 'Belohnung und Fortschritt im Fokus.',
      icon: Icons.emoji_events_rounded,
      defaultBlocks: [
        {'type': 'loyalty', 'order': 0, 'isVisible': true, 'value': {'title': 'Nächste Belohnung', 'description': '', 'rewardText': '', 'showQr': false}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 1, 'isVisible': true, 'value': {'content': 'Bereits X Punkte gesammelt', 'fontSize': 16.0, 'fontWeight': 'normal', 'color': '#DDDDDD', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 2, 'isVisible': true, 'value': {'targetType': 'wallet', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Punkte ansehen'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── FEED ─────────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'feed_socialwall',
      type: DisplayLayoutType.feed,
      name: 'Social Wall',
      description: 'Aktionen und Posts als lebendige Wall.',
      icon: Icons.dynamic_feed_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Aktuelle Beiträge', 'fontSize': 22.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'image', 'order': 1, 'isVisible': true, 'value': {'url': '', 'fit': 'cover'}, 'sourceType': 'feedPost', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 2, 'isVisible': true, 'value': {'content': '', 'fontSize': 16.0, 'fontWeight': 'normal', 'color': '#FFFFFF', 'alignment': 'left'}, 'sourceType': 'feedPost', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 3, 'isVisible': true, 'value': {'targetType': 'shop', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Mehr erfahren'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'feed_highlight',
      type: DisplayLayoutType.feed,
      name: 'Highlight Post',
      description: 'Einen einzelnen Post groß hervorheben.',
      icon: Icons.featured_play_list_rounded,
      defaultBlocks: [
        {'type': 'image', 'order': 0, 'isVisible': true, 'value': {'url': '', 'fit': 'cover'}, 'sourceType': 'feedPost', 'sourceId': '', 'style': {}},
        {'type': 'badge', 'order': 1, 'isVisible': true, 'value': {'text': 'NEU', 'backgroundColor': '#007AFF', 'textColor': '#FFFFFF'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 2, 'isVisible': true, 'value': {'content': '', 'fontSize': 20.0, 'fontWeight': 'bold', 'color': '#FFFFFF', 'alignment': 'left'}, 'sourceType': 'feedPost', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── ORDERS ────────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'orders_statusboard',
      type: DisplayLayoutType.orders,
      name: 'Order Status Board',
      description: 'Bestellstatus für Küche oder Ausgabe.',
      icon: Icons.receipt_long_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Bestellungen', 'fontSize': 26.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'divider', 'order': 1, 'isVisible': true, 'value': {'color': '#FFFFFF', 'thickness': 1.0, 'opacity': 0.2}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 2, 'isVisible': true, 'value': {'content': 'Wird vorbereitet…', 'fontSize': 18.0, 'fontWeight': 'normal', 'color': '#DDDDDD', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'orders_pickup',
      type: DisplayLayoutType.orders,
      name: 'Pickup Numbers',
      description: 'Nummern für Abholung klar anzeigen.',
      icon: Icons.numbers_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Bereit zur Abholung', 'fontSize': 24.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 1, 'isVisible': true, 'value': {'content': '#001  #002  #003', 'fontSize': 40.0, 'fontWeight': 'black', 'color': '#9CE8CF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── FREE ─────────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'free_blank',
      type: DisplayLayoutType.free,
      name: 'Blank Clean',
      description: 'Leere Fläche – vollständige Freiheit.',
      icon: Icons.crop_square_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Dein Text', 'fontSize': 24.0, 'fontWeight': 'bold', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'free_poster',
      type: DisplayLayoutType.free,
      name: 'Poster Basic',
      description: 'Bild + Titel + Untertitel wie ein Poster.',
      icon: Icons.photo_size_select_actual_rounded,
      defaultBlocks: [
        {'type': 'image', 'order': 0, 'isVisible': true, 'value': {'url': '', 'fit': 'cover'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 1, 'isVisible': true, 'value': {'content': 'Titel', 'fontSize': 28.0, 'fontWeight': 'black', 'color': '#FFFFFF', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'text', 'order': 2, 'isVisible': true, 'value': {'content': 'Untertitel', 'fontSize': 16.0, 'fontWeight': 'normal', 'color': '#CCCCCC', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),

    // ── REVIEW ───────────────────────────────────────────────────────────────
    DisplayTemplate(
      id: 'review_quotewall',
      type: DisplayLayoutType.review,
      name: 'Quote Wall',
      description: 'Kundenzitate groß und wirkungsvoll.',
      icon: Icons.format_quote_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': 'Was unsere Gäste sagen', 'fontSize': 18.0, 'fontWeight': 'bold', 'color': '#AAAAAA', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'review', 'order': 1, 'isVisible': true, 'value': {'text': '', 'authorName': '', 'rating': 5, 'source': ''}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 2, 'isVisible': true, 'value': {'targetType': 'review', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Bewertung hinterlassen'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
    DisplayTemplate(
      id: 'review_rating',
      type: DisplayLayoutType.review,
      name: 'Rating Highlight',
      description: 'Sternebewertung mit Gesamtpunktzahl.',
      icon: Icons.star_rounded,
      defaultBlocks: [
        {'type': 'text', 'order': 0, 'isVisible': true, 'value': {'content': '⭐ 4,8 / 5,0', 'fontSize': 36.0, 'fontWeight': 'black', 'color': '#FFD60A', 'alignment': 'center'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'review', 'order': 1, 'isVisible': true, 'value': {'text': '', 'authorName': '', 'rating': 5, 'source': ''}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
        {'type': 'qr', 'order': 2, 'isVisible': true, 'value': {'targetType': 'review', 'targetUrl': '', 'targetId': '', 'showLabel': true, 'label': 'Jetzt bewerten'}, 'sourceType': 'manual', 'sourceId': '', 'style': {}},
      ],
    ),
  ];

  static List<DisplayTemplate> forType(DisplayLayoutType type) =>
      all.where((t) => t.type == type).toList();
}
