import 'dart:math';

enum DisplayBlockType {
  text,
  price,
  image,
  qr,
  badge,
  menuList,
  gallery,
  loyalty,
  review,
  divider,
  spacer;

  String get label {
    switch (this) {
      case text:
        return 'Text';
      case price:
        return 'Preis';
      case image:
        return 'Bild';
      case qr:
        return 'QR-Code';
      case badge:
        return 'Badge';
      case menuList:
        return 'Menüliste';
      case gallery:
        return 'Galerie';
      case loyalty:
        return 'Loyalty';
      case review:
        return 'Bewertung';
      case divider:
        return 'Trennlinie';
      case spacer:
        return 'Abstand';
    }
  }

  static DisplayBlockType fromString(String? v) =>
      DisplayBlockType.values.firstWhere((e) => e.name == v,
          orElse: () => DisplayBlockType.text);
}

class DisplayBlock {
  const DisplayBlock({
    required this.id,
    required this.type,
    required this.value,
    this.sourceType = 'manual',
    this.sourceId = '',
    this.style = const {},
    required this.order,
    this.isVisible = true,
  });

  final String id;
  final DisplayBlockType type;
  final Map<String, dynamic> value;
  final String sourceType; // 'manual' | 'menuItem' | 'feedPost' | 'stamp'
  final String sourceId;
  final Map<String, dynamic> style;
  final int order;
  final bool isVisible;

  static String _newId() {
    final rng = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = rng.nextInt(0xFFFF);
    return '${ts.toRadixString(16)}${rand.toRadixString(16)}';
  }

  // ── Default value maps per type ───────────────────────────────────────────

  static Map<String, dynamic> defaultValue(DisplayBlockType type) {
    switch (type) {
      case DisplayBlockType.text:
        return {
          'content': '',
          'fontSize': 20.0,
          'fontWeight': 'bold',
          'color': '#FFFFFF',
          'alignment': 'center',
        };
      case DisplayBlockType.price:
        return {
          'price': '',
          'oldPrice': '',
          'currency': '€',
          'color': '#FFFFFF',
        };
      case DisplayBlockType.image:
        return {'url': '', 'fit': 'cover'};
      case DisplayBlockType.qr:
        return {
          'targetType': 'shop',
          'targetUrl': '',
          'targetId': '',
          'showLabel': true,
          'label': 'Hier scannen',
        };
      case DisplayBlockType.badge:
        return {
          'text': '',
          'backgroundColor': '#FF3B30',
          'textColor': '#FFFFFF',
        };
      case DisplayBlockType.menuList:
        return {
          'items': <Map<String, dynamic>>[],
          'showBorder': true,
          'color': '#FFFFFF',
        };
      case DisplayBlockType.gallery:
        return {
          'urls': <String>[],
          'durationSeconds': 4,
          'effect': 'fade',
        };
      case DisplayBlockType.loyalty:
        return {
          'title': '',
          'description': '',
          'rewardText': '',
          'showQr': false,
        };
      case DisplayBlockType.review:
        return {
          'text': '',
          'authorName': '',
          'rating': 5,
          'source': '',
        };
      case DisplayBlockType.divider:
        return {'color': '#FFFFFF', 'thickness': 1.0, 'opacity': 0.3};
      case DisplayBlockType.spacer:
        return {'height': 16.0};
    }
  }

  // ── Factories ─────────────────────────────────────────────────────────────

  factory DisplayBlock.create(DisplayBlockType type, {int order = 0}) {
    return DisplayBlock(
      id: _newId(),
      type: type,
      value: defaultValue(type),
      order: order,
    );
  }

  factory DisplayBlock.fromMap(Map<String, dynamic> map) {
    final rawValue = map['value'];
    final rawStyle = map['style'];
    return DisplayBlock(
      id: map['id'] as String? ?? _newId(),
      type: DisplayBlockType.fromString(map['type'] as String?),
      value: rawValue is Map<String, dynamic> ? Map<String, dynamic>.from(rawValue) : {},
      sourceType: map['sourceType'] as String? ?? 'manual',
      sourceId: map['sourceId'] as String? ?? '',
      style: rawStyle is Map<String, dynamic> ? Map<String, dynamic>.from(rawStyle) : {},
      order: (map['order'] as num?)?.toInt() ?? 0,
      isVisible: map['isVisible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'value': value,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'style': style,
        'order': order,
        'isVisible': isVisible,
      };

  DisplayBlock copyWith({
    DisplayBlockType? type,
    Map<String, dynamic>? value,
    String? sourceType,
    String? sourceId,
    Map<String, dynamic>? style,
    int? order,
    bool? isVisible,
  }) {
    return DisplayBlock(
      id: id,
      type: type ?? this.type,
      value: value ?? this.value,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      style: style ?? this.style,
      order: order ?? this.order,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  /// Human-readable preview of the block content
  String get previewText {
    switch (type) {
      case DisplayBlockType.text:
        final c = value['content'] as String? ?? '';
        return c.isEmpty ? '(Leer)' : c;
      case DisplayBlockType.price:
        final p = value['price'] as String? ?? '';
        final cur = value['currency'] as String? ?? '€';
        return p.isEmpty ? '(Preis)' : '$p $cur';
      case DisplayBlockType.image:
        final url = value['url'] as String? ?? '';
        return url.isEmpty ? '(Kein Bild)' : 'Bild gesetzt';
      case DisplayBlockType.qr:
        final t = value['targetType'] as String? ?? '';
        return 'QR → $t';
      case DisplayBlockType.badge:
        final t = value['text'] as String? ?? '';
        return t.isEmpty ? '(Badge)' : t;
      case DisplayBlockType.menuList:
        final items = value['items'] as List? ?? [];
        return '${items.length} Einträge';
      case DisplayBlockType.gallery:
        final urls = value['urls'] as List? ?? [];
        return '${urls.length} Bilder';
      case DisplayBlockType.loyalty:
        final t = value['title'] as String? ?? '';
        return t.isEmpty ? '(Loyalty)' : t;
      case DisplayBlockType.review:
        final t = value['text'] as String? ?? '';
        return t.isEmpty ? '(Bewertung)' : t;
      case DisplayBlockType.divider:
        return 'Trennlinie';
      case DisplayBlockType.spacer:
        final h = value['height'] ?? 16;
        return '$h px Abstand';
    }
  }
}
