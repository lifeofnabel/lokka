import 'package:cloud_firestore/cloud_firestore.dart';

enum DisplayLayoutType {
  deal,
  menu,
  gallery,
  qr,
  loyalty,
  orders,
  free,
  feed,
  review;

  String get label {
    switch (this) {
      case deal:
        return 'Angebot';
      case menu:
        return 'Menü';
      case gallery:
        return 'Galerie';
      case qr:
        return 'QR-Code';
      case loyalty:
        return 'Treue';
      case orders:
        return 'Bestellungen';
      case free:
        return 'Frei';
      case feed:
        return 'Feed';
      case review:
        return 'Bewertung';
    }
  }

  static DisplayLayoutType fromString(String? value) {
    return DisplayLayoutType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DisplayLayoutType.free,
    );
  }
}

enum DisplayOrientation {
  landscape,
  portrait;

  String get label => this == landscape ? 'Querformat' : 'Hochformat';

  static DisplayOrientation fromString(String? value) {
    return value == 'portrait' ? DisplayOrientation.portrait : DisplayOrientation.landscape;
  }
}

class DisplayLayout {
  const DisplayLayout({
    required this.id,
    required this.title,
    required this.type,
    required this.orientation,
    required this.screenSizeTarget,
    required this.mode,
    required this.templateId,
    required this.coverUrl,
    required this.blocks,
    required this.animation,
    required this.tags,
    required this.isDraft,
    this.backgroundStyle = 'dark',
    required this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DisplayLayoutType type;
  final DisplayOrientation orientation;
  final String screenSizeTarget;
  final String mode;
  final String templateId;
  final String coverUrl;
  final List<Map<String, dynamic>> blocks;
  final String animation;
  final List<String> tags;
  final bool isDraft;
  final String backgroundStyle; // 'dark' | 'light' | 'image'
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DisplayLayout.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return DisplayLayout.fromMap(map, id: doc.id);
  }

  factory DisplayLayout.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final rawBlocks = map['blocks'];
    final blocks = rawBlocks is List
        ? rawBlocks.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final rawTags = map['tags'];
    final tags = rawTags is List ? rawTags.map((e) => e.toString()).toList() : <String>[];
    return DisplayLayout(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      type: DisplayLayoutType.fromString(map['type'] as String?),
      orientation: DisplayOrientation.fromString(map['orientation'] as String?),
      screenSizeTarget: map['screenSizeTarget'] as String? ?? '',
      mode: map['mode'] as String? ?? 'static',
      templateId: map['templateId'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      blocks: blocks,
      animation: map['animation'] as String? ?? 'fade',
      tags: tags,
      isDraft: map['isDraft'] as bool? ?? true,
      backgroundStyle: map['backgroundStyle'] as String? ?? 'dark',
      lastUsedAt: (map['lastUsedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type.name,
        'orientation': orientation.name,
        'screenSizeTarget': screenSizeTarget,
        'mode': mode,
        'templateId': templateId,
        'coverUrl': coverUrl,
        'blocks': blocks,
        'animation': animation,
        'tags': tags,
        'isDraft': isDraft,
        'backgroundStyle': backgroundStyle,
        'lastUsedAt': lastUsedAt != null ? Timestamp.fromDate(lastUsedAt!) : null,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  DisplayLayout copyWith({
    String? id,
    String? title,
    DisplayLayoutType? type,
    DisplayOrientation? orientation,
    String? screenSizeTarget,
    String? mode,
    String? templateId,
    String? coverUrl,
    List<Map<String, dynamic>>? blocks,
    String? animation,
    List<String>? tags,
    bool? isDraft,
    String? backgroundStyle,
  }) {
    return DisplayLayout(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      orientation: orientation ?? this.orientation,
      screenSizeTarget: screenSizeTarget ?? this.screenSizeTarget,
      mode: mode ?? this.mode,
      templateId: templateId ?? this.templateId,
      coverUrl: coverUrl ?? this.coverUrl,
      blocks: blocks ?? this.blocks,
      animation: animation ?? this.animation,
      tags: tags ?? this.tags,
      isDraft: isDraft ?? this.isDraft,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Auto-generate tags based on layout properties
  List<String> get autoTags {
    final result = <String>[];
    result.add(type.label);
    result.add(orientation.label);
    if (screenSizeTarget.isNotEmpty) result.add(screenSizeTarget);
    if (mode == 'day') result.add('Tag');
    if (mode == 'night') result.add('Nacht');
    result.add(_animationLabel(animation));
    return result;
  }

  static String _animationLabel(String a) {
    switch (a) {
      case 'slide':
        return 'Slide';
      case 'softZoom':
        return 'Soft Zoom';
      case 'cardSwitch':
        return 'Card Switch';
      default:
        return 'Fade';
    }
  }
}
