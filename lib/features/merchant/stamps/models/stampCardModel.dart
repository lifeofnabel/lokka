import 'package:cloud_firestore/cloud_firestore.dart';

class StampCardStatus {
  const StampCardStatus._();

  static const draft = 'draft';
  static const active = 'active';
  static const paused = 'paused';
  static const archived = 'archived';
}

class StampConditionType {
  const StampConditionType._();

  static const minimumAmount = 'minimumAmount';
  static const item = 'item';
  static const visit = 'visit';
  static const custom = 'custom';
}

class StampRewardType {
  const StampRewardType._();

  static const item = 'item';
  static const custom = 'custom';
  static const discount = 'discount';
  static const free = 'free';
}

/// A single reward milestone on a stamp card. A "simple" card (X stamps = 1
/// reward) is just a single tier at `atStamp == requiredStamps`; a "tiered"
/// card has several (e.g. 5 = discount, 10 = free). Modelling everything as a
/// list keeps one code path — never two.
class StampRewardTier {
  const StampRewardTier({
    required this.atStamp,
    required this.type,
    required this.label,
    this.itemId = '',
    this.itemName = '',
  });

  /// Stamp count at which this reward unlocks (1-based).
  final int atStamp;

  /// One of [StampRewardType] (item | custom | discount | free).
  final String type;

  /// Human-facing reward label, e.g. "Gratis-Falafel" or "20% Rabatt".
  final String label;

  /// Optional linked catalog item (for [StampRewardType.item]).
  final String itemId;
  final String itemName;

  factory StampRewardTier.fromMap(Map<String, dynamic> map) {
    return StampRewardTier(
      atStamp: StampCardModel._readInt(map['atStamp'], fallback: 1),
      type: (map['type'] ?? StampRewardType.custom).toString(),
      label: (map['label'] ?? '').toString(),
      itemId: (map['itemId'] ?? '').toString(),
      itemName: (map['itemName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'atStamp': atStamp,
        'type': type,
        'label': label.trim(),
        'itemId': itemId,
        'itemName': itemName,
      };

  StampRewardTier copyWith({
    int? atStamp,
    String? type,
    String? label,
    String? itemId,
    String? itemName,
  }) {
    return StampRewardTier(
      atStamp: atStamp ?? this.atStamp,
      type: type ?? this.type,
      label: label ?? this.label,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
    );
  }
}

class StampCardModel {
  const StampCardModel({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.requiredStamps,
    required this.conditionType,
    required this.minimumAmount,
    required this.requiredItemId,
    required this.requiredItemName,
    required this.conditionText,
    required this.rewardType,
    required this.rewardItemId,
    required this.rewardItemName,
    required this.rewardTitle,
    required this.rewardDescription,
    this.rewardTiers = const [],
    this.boundStickId = '',
    this.staticToken = '',
    this.stickType = '',
    this.stickVerifiedAt,
    this.maxDistribution,
    this.distributedCount = 0,
    required this.backgroundColor,
    required this.gradientColor,
    required this.gradientEnabled,
    required this.accentColor,
    required this.textColor,
    required this.styleName,
    required this.stampShape,
    required this.stampIconType,
    required this.stampIconValue,
    required this.imageUrl,
    required this.imagePlacement,
    required this.claimLimits,
    required this.status,
    required this.isActive,
    required this.isArchived,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.activatedAt,
    this.pausedAt,
    this.archivedAt,
  });

  final String id;
  final String merchantId;
  final String title;
  final String subtitle;
  final String description;
  final int requiredStamps;
  final String conditionType;
  final num? minimumAmount;
  final String requiredItemId;
  final String requiredItemName;
  final String conditionText;
  final String rewardType;
  final String rewardItemId;
  final String rewardItemName;
  final String rewardTitle;
  final String rewardDescription;

  /// Ordered reward milestones. Empty means "legacy single reward" — use
  /// [effectiveRewardTiers] to always get a normalised list.
  final List<StampRewardTier> rewardTiers;

  /// ID of the physical stamp stick (NTAG 424 DNA / QR) bound to this card, or
  /// empty when no stick is connected yet.
  final String boundStickId;

  /// Signed static-link token, prepared the moment the card goes live. The
  /// shareable tap link is `<app-base>/s/<staticToken>`. Public (it's what goes
  /// on a tag), so it's safe to keep on the card and copy instantly — no
  /// server round-trip at copy time.
  final String staticToken;

  /// Stick kind: 'static' (browser-written link) | 'ntag424' (pre-provisioned).
  /// Server-managed mirror; the client only reads it.
  final String stickType;

  /// When the bound stick passed a Test-Tap. Null until verified — the
  /// "Stift verbunden ✓" badge only shows once this is set. Server-managed.
  final DateTime? stickVerifiedAt;

  /// Optional cap on how many DISTINCT customers may ever hold this card (a
  /// limited-edition drop, e.g. "only the first 50"). Null = unlimited.
  /// Merchant-editable — included in [toMap].
  final int? maxDistribution;

  /// How many distinct customers have received this card so far. 100%
  /// server-owned (bumped by Cloud Functions the moment a customer's first
  /// stamp lands) — deliberately excluded from [toMap] so a merchant save can
  /// never clobber it; `setDocument`'s merge-write leaves absent fields alone.
  final int distributedCount;

  final String backgroundColor;
  final String gradientColor;
  final bool gradientEnabled;
  final String accentColor;
  final String textColor;
  final String styleName;
  final String stampShape;
  final String stampIconType;
  final String stampIconValue;
  final String imageUrl;
  final String imagePlacement;
  final Map<String, dynamic> claimLimits;
  final String status;
  final bool isActive;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? activatedAt;
  final DateTime? pausedAt;
  final DateTime? archivedAt;

  bool get isDraft => status == StampCardStatus.draft;
  bool get isLive => status == StampCardStatus.active && isActive;
  bool get isPaused => status == StampCardStatus.paused;
  bool get isArchivedCard => status == StampCardStatus.archived || isArchived;

  bool get hasStick => boundStickId.isNotEmpty;

  /// A shareable tap link has been prepared for this card.
  bool get hasLink => staticToken.isNotEmpty;

  /// A stick is connected AND passed its Test-Tap → show "Stift verbunden ✓".
  bool get stickVerified => stickVerifiedAt != null;

  /// Slots left before the supply cap is reached. Null = unlimited.
  int? get remainingDistribution =>
      maxDistribution == null ? null : (maxDistribution! - distributedCount).clamp(0, maxDistribution!);

  /// A cap is set and every slot has already gone to a customer.
  bool get isDistributionFull =>
      maxDistribution != null && distributedCount >= maxDistribution!;

  /// Normalised reward milestones, sorted ascending by [StampRewardTier.atStamp].
  /// Falls back to a single tier synthesised from the legacy reward fields so
  /// old cards keep working with the tiered code path.
  List<StampRewardTier> get effectiveRewardTiers {
    if (rewardTiers.isNotEmpty) {
      final sorted = [...rewardTiers]
        ..sort((a, b) => a.atStamp.compareTo(b.atStamp));
      return sorted;
    }
    return [
      StampRewardTier(
        atStamp: requiredStamps,
        type: rewardType,
        label: rewardTitle.isNotEmpty
            ? rewardTitle
            : (rewardItemName.isNotEmpty ? rewardItemName : rewardDescription),
        itemId: rewardItemId,
        itemName: rewardItemName,
      ),
    ];
  }

  /// The final milestone count — how many stamps complete the whole card.
  int get maxStamps {
    final tiers = effectiveRewardTiers;
    final tierMax = tiers.isEmpty ? 0 : tiers.last.atStamp;
    return tierMax > requiredStamps ? tierMax : requiredStamps;
  }

  factory StampCardModel.empty({required String merchantId}) {
    return StampCardModel(
      id: '',
      merchantId: merchantId,
      title: '',
      subtitle: '',
      description: '',
      requiredStamps: 10,
      conditionType: StampConditionType.visit,
      minimumAmount: null,
      requiredItemId: '',
      requiredItemName: '',
      conditionText: '',
      rewardType: StampRewardType.custom,
      rewardItemId: '',
      rewardItemName: '',
      rewardTitle: '',
      rewardDescription: '',
      rewardTiers: const [],
      boundStickId: '',
      maxDistribution: null,
      distributedCount: 0,
      backgroundColor: '#171A18',
      gradientColor: '#45C9A4',
      gradientEnabled: false,
      accentColor: '#9CE8CF',
      textColor: '#FEFFFC',
      styleName: 'noir',
      stampShape: 'circle',
      stampIconType: 'icon',
      stampIconValue: 'star',
      imageUrl: '',
      imagePlacement: 'side',
      claimLimits: const {'perUser': null, 'perDay': null},
      status: StampCardStatus.draft,
      isActive: false,
      isArchived: false,
    );
  }

  factory StampCardModel.fromMap(Map<String, dynamic> map) {
    return StampCardModel(
      id: (map['id'] ?? map['stampCardId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      requiredStamps: _readInt(map['requiredStamps'], fallback: 10),
      conditionType: (map['conditionType'] ?? StampConditionType.visit).toString(),
      minimumAmount: map['minimumAmount'] is num ? map['minimumAmount'] as num : num.tryParse((map['minimumAmount'] ?? '').toString()),
      requiredItemId: (map['requiredItemId'] ?? '').toString(),
      requiredItemName: (map['requiredItemName'] ?? '').toString(),
      conditionText: (map['conditionText'] ?? '').toString(),
      rewardType: (map['rewardType'] ?? StampRewardType.custom).toString(),
      rewardItemId: (map['rewardItemId'] ?? '').toString(),
      rewardItemName: (map['rewardItemName'] ?? '').toString(),
      rewardTitle: (map['rewardTitle'] ?? '').toString(),
      rewardDescription: (map['rewardDescription'] ?? '').toString(),
      rewardTiers: (map['rewardTiers'] as List?)
              ?.whereType<Map>()
              .map((e) => StampRewardTier.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      boundStickId: (map['boundStickId'] ?? '').toString(),
      staticToken: (map['staticToken'] ?? '').toString(),
      stickType: (map['stickType'] ?? '').toString(),
      stickVerifiedAt: _readDateTime(map['stickVerifiedAt']),
      maxDistribution: (() {
        final raw = map['maxDistribution'];
        if (raw == null) return null;
        final n = raw is num ? raw.round() : int.tryParse(raw.toString());
        return (n != null && n > 0) ? n : null;
      })(),
      distributedCount: _readInt(map['distributedCount'], fallback: 0),
      backgroundColor: (map['backgroundColor'] ?? '#171A18').toString(),
      gradientColor: (map['gradientColor'] ?? '#45C9A4').toString(),
      gradientEnabled: map['gradientEnabled'] as bool? ?? false,
      accentColor: (map['accentColor'] ?? '#9CE8CF').toString(),
      textColor: (map['textColor'] ?? '#FEFFFC').toString(),
      styleName: (map['styleName'] ?? 'noir').toString(),
      stampShape: (map['stampShape'] ?? 'circle').toString(),
      stampIconType: (map['stampIconType'] ?? 'icon').toString(),
      stampIconValue: (map['stampIconValue'] ?? 'star').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      imagePlacement: (map['imagePlacement'] ?? 'side').toString(),
      claimLimits: Map<String, dynamic>.from(map['claimLimits'] as Map? ?? const {'perUser': null, 'perDay': null}),
      status: (map['status'] ?? StampCardStatus.draft).toString(),
      isActive: map['isActive'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
      publishedAt: _readDateTime(map['publishedAt']),
      activatedAt: _readDateTime(map['activatedAt']),
      pausedAt: _readDateTime(map['pausedAt']),
      archivedAt: _readDateTime(map['archivedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stampCardId': id,
      'merchantId': merchantId,
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'requiredStamps': requiredStamps,
      'conditionType': conditionType,
      'minimumAmount': minimumAmount,
      'requiredItemId': requiredItemId,
      'requiredItemName': requiredItemName,
      'conditionText': conditionText.trim(),
      'rewardType': rewardType,
      'rewardItemId': rewardItemId,
      'rewardItemName': rewardItemName,
      'rewardTitle': rewardTitle.trim(),
      'rewardDescription': rewardDescription.trim(),
      'rewardTiers': rewardTiers.map((t) => t.toMap()).toList(),
      'boundStickId': boundStickId,
      // Preserved across full-replace saves so the prepared link is never lost.
      'staticToken': staticToken,
      // Stift-Metadaten mitschreiben, damit ein späteres Speichern/Veröffentlichen
      // die verbundenen Stift-Infos (Typ + Verifiziert-Zeitpunkt) nicht löscht.
      'stickType': stickType,
      'maxDistribution': maxDistribution,
      // distributedCount ist bewusst NICHT enthalten: 100% server-verwaltet
      // (Cloud-Function-Increment). setDocument merged standardmäßig, ein
      // fehlendes Feld bleibt also unangetastet — kein Race mit Merchant-Saves.
      'backgroundColor': backgroundColor,
      'gradientColor': gradientColor,
      'gradientEnabled': gradientEnabled,
      'accentColor': accentColor,
      'textColor': textColor,
      'styleName': styleName,
      'stampShape': stampShape,
      'stampIconType': stampIconType,
      'stampIconValue': stampIconValue,
      'imageUrl': imageUrl,
      'imagePlacement': imagePlacement,
      'claimLimits': claimLimits,
      'status': status,
      'isActive': isActive,
      'isArchived': isArchived,
      if (stickVerifiedAt != null)
        'stickVerifiedAt': Timestamp.fromDate(stickVerifiedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      if (pausedAt != null) 'pausedAt': Timestamp.fromDate(pausedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
    };
  }

  StampCardModel copyWith({
    String? id,
    String? merchantId,
    String? title,
    String? subtitle,
    String? description,
    int? requiredStamps,
    String? conditionType,
    num? minimumAmount,
    String? requiredItemId,
    String? requiredItemName,
    String? conditionText,
    String? rewardType,
    String? rewardItemId,
    String? rewardItemName,
    String? rewardTitle,
    String? rewardDescription,
    List<StampRewardTier>? rewardTiers,
    String? boundStickId,
    String? staticToken,
    String? stickType,
    DateTime? stickVerifiedAt,
    int? maxDistribution,
    bool clearMaxDistribution = false,
    int? distributedCount,
    String? backgroundColor,
    String? gradientColor,
    bool? gradientEnabled,
    String? accentColor,
    String? textColor,
    String? styleName,
    String? stampShape,
    String? stampIconType,
    String? stampIconValue,
    String? imageUrl,
    String? imagePlacement,
    Map<String, dynamic>? claimLimits,
    String? status,
    bool? isActive,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? activatedAt,
    DateTime? pausedAt,
    DateTime? archivedAt,
  }) {
    return StampCardModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      requiredStamps: requiredStamps ?? this.requiredStamps,
      conditionType: conditionType ?? this.conditionType,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      requiredItemId: requiredItemId ?? this.requiredItemId,
      requiredItemName: requiredItemName ?? this.requiredItemName,
      conditionText: conditionText ?? this.conditionText,
      rewardType: rewardType ?? this.rewardType,
      rewardItemId: rewardItemId ?? this.rewardItemId,
      rewardItemName: rewardItemName ?? this.rewardItemName,
      rewardTitle: rewardTitle ?? this.rewardTitle,
      rewardDescription: rewardDescription ?? this.rewardDescription,
      rewardTiers: rewardTiers ?? this.rewardTiers,
      boundStickId: boundStickId ?? this.boundStickId,
      staticToken: staticToken ?? this.staticToken,
      stickType: stickType ?? this.stickType,
      stickVerifiedAt: stickVerifiedAt ?? this.stickVerifiedAt,
      maxDistribution:
          clearMaxDistribution ? null : (maxDistribution ?? this.maxDistribution),
      distributedCount: distributedCount ?? this.distributedCount,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gradientColor: gradientColor ?? this.gradientColor,
      gradientEnabled: gradientEnabled ?? this.gradientEnabled,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      styleName: styleName ?? this.styleName,
      stampShape: stampShape ?? this.stampShape,
      stampIconType: stampIconType ?? this.stampIconType,
      stampIconValue: stampIconValue ?? this.stampIconValue,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePlacement: imagePlacement ?? this.imagePlacement,
      claimLimits: claimLimits ?? this.claimLimits,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
