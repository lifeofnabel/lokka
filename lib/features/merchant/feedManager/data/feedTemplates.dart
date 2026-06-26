/// The post templates offered in the "Beitrag erstellen" chooser, split into two
/// groups (general vs. action). Each maps to an existing post `type` (so the
/// data layer / feed markers stay unchanged) and carries ready-made German
/// starter copy so a merchant only taps + lightly edits — minimal typing,
/// senior-friendly.
///
/// Suggestion strings are intentionally German content (the merchant edits them
/// before publishing); structural labels/names are translated via i18n.
library;

enum FeedTemplateGroup { general, action }

class FeedTemplate {
  const FeedTemplate({
    required this.type,
    required this.group,
    this.needsPrice = false,
    this.needsPercent = false,
    this.needsTimeWindow = false,
    this.needsCategory = false,
    this.catalogTarget,
    this.subtitleSuggestions = const [],
    this.descriptionSuggestions = const [],
  });

  /// Stored on the post; drives the feed marker + existing createPost logic.
  final String type;
  final FeedTemplateGroup group;

  // Which structured fields the fill step surfaces (kept minimal + inline).
  final bool needsPrice; // old/new price
  final bool needsPercent; // discount %
  final bool needsTimeWindow; // happy-hour from/to
  final bool needsCategory; // discount on a category

  /// Items to link from the menu (1+1 → 2, 2+1 → 3). null = free choice.
  final int? catalogTarget;

  /// Tap-to-fill starter copy. `{cat}` in a discount subtitle is replaced by the
  /// chosen category.
  final List<String> subtitleSuggestions;
  final List<String> descriptionSuggestions;

  bool get isAction => group == FeedTemplateGroup.action;
}

const List<FeedTemplate> kFeedTemplates = [
  // ── Allgemeiner Beitrag ────────────────────────────────────────────────────
  FeedTemplate(
    type: 'news',
    group: FeedTemplateGroup.general,
    subtitleSuggestions: ['Frisch bei uns', 'Das ist neu', 'Kurz & wichtig'],
    descriptionSuggestions: [
      'Wir haben Neuigkeiten für euch – schaut vorbei!',
      'Ab sofort bei uns. Wir freuen uns auf euren Besuch.',
    ],
  ),
  FeedTemplate(
    type: 'newProduct',
    group: FeedTemplateGroup.general,
    subtitleSuggestions: ['Neu im Sortiment', 'Ab heute erhältlich', 'Frisch eingetroffen'],
    descriptionSuggestions: [
      'Probiert unsere neue Ware – ab sofort bei uns erhältlich.',
      'Frisch eingetroffen und bereit für euch.',
    ],
  ),
  FeedTemplate(
    type: 'info', // "Warnung"
    group: FeedTemplateGroup.general,
    subtitleSuggestions: ['Bitte beachten', 'Kurzfristige Info', 'Wichtiger Hinweis'],
    descriptionSuggestions: [
      'Kurzer Hinweis von uns: ',
      'Bitte beachtet folgende Information: ',
    ],
  ),
  FeedTemplate(
    type: 'communityEvent',
    group: FeedTemplateGroup.general,
    subtitleSuggestions: ['Save the date', 'Bei uns ist was los', 'Kommt vorbei'],
    descriptionSuggestions: [
      'Wir laden euch herzlich ein. Datum & Uhrzeit: ',
      'Feiert mit uns – wir freuen uns auf euch!',
    ],
  ),
  FeedTemplate(
    type: 'hiring',
    group: FeedTemplateGroup.general,
    subtitleSuggestions: ['Wir stellen ein', 'Verstärkung gesucht', 'Werde Teil des Teams'],
    descriptionSuggestions: [
      'Wir suchen Verstärkung für unser Team. Melde dich bei uns!',
      'Lust mitzuarbeiten? Wir freuen uns auf deine Bewerbung.',
    ],
  ),
  // ── Neue Aktion ────────────────────────────────────────────────────────────
  FeedTemplate(
    type: 'offer',
    group: FeedTemplateGroup.action,
    needsPrice: true,
    subtitleSuggestions: ['Nur für kurze Zeit', 'Solange der Vorrat reicht', 'Heute besonders günstig'],
    descriptionSuggestions: [
      'Sichert euch unser Sonderangebot – nur für kurze Zeit!',
      'Greift zu, solange der Vorrat reicht.',
    ],
  ),
  FeedTemplate(
    type: 'categoryDiscountPercent', // "Rabatt"
    group: FeedTemplateGroup.action,
    needsPercent: true,
    needsCategory: true,
    subtitleSuggestions: ['Auf {cat}', 'Spar-Aktion', 'Rabatt-Tage'],
    descriptionSuggestions: [
      'Jetzt sparen auf {cat} – nur für kurze Zeit!',
      'Rabatt auf {cat}. Kommt vorbei und spart.',
    ],
  ),
  FeedTemplate(
    type: 'happyHour',
    group: FeedTemplateGroup.action,
    needsTimeWindow: true,
    subtitleSuggestions: ['Jeden Tag 17–19 Uhr', 'Happy Hour bei uns', '2 Stunden, beste Preise'],
    descriptionSuggestions: [
      'Während der Happy Hour gibt es beste Preise – kommt vorbei!',
      'Happy Hour: ausgewählte Artikel günstiger. Nur in diesem Zeitfenster.',
    ],
  ),
  FeedTemplate(
    type: 'onePlusOneFree',
    group: FeedTemplateGroup.action,
    catalogTarget: 2,
    subtitleSuggestions: ['Kauf 1, nimm 2', '1+1 geschenkt', 'Doppelt genießen'],
    descriptionSuggestions: [
      "Bei uns gibt's 1+1 gratis – das zweite geht aufs Haus!",
      'Kauf eins, bekomm eins gratis dazu.',
    ],
  ),
  FeedTemplate(
    type: 'twoPlusOneFree',
    group: FeedTemplateGroup.action,
    catalogTarget: 3,
    subtitleSuggestions: ['Kauf 2, nimm 3', '2+1 geschenkt', 'Das dritte gratis'],
    descriptionSuggestions: [
      '2+1 gratis bei uns – das dritte ist geschenkt!',
      'Nimm drei, zahl zwei.',
    ],
  ),
  FeedTemplate(
    type: 'rescueMe', // "Retter Deal"
    group: FeedTemplateGroup.action,
    needsPrice: true,
    subtitleSuggestions: ['Rette mich!', 'Heute noch zu haben', 'Gegen Verschwendung'],
    descriptionSuggestions: [
      "Heute übrig – zum kleinen Preis, bevor's weg ist. Rette Lebensmittel!",
      'Statt wegwerfen: schnapp dir unseren Retter-Deal zum kleinen Preis.',
      'Letzte Stücke des Tages – günstig abzugeben gegen Verschwendung.',
    ],
  ),
];

FeedTemplate? feedTemplateForType(String type) {
  for (final t in kFeedTemplates) {
    if (t.type == type) return t;
  }
  return null;
}

List<FeedTemplate> feedTemplatesIn(FeedTemplateGroup group) =>
    kFeedTemplates.where((t) => t.group == group).toList(growable: false);
