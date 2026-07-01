/// Lokalisiertes Label je Beitrags-Typ. EINE Quelle der Wahrheit – vorher in
/// `userDiscoverPage.dart` UND `userExplorePage.dart` dupliziert (zwei
/// identische Top-Level-Funktionen, die hätten auseinanderdriften können).
String feedTypeLabel(String type) => _feedTypeLabels[type] ?? type;

const Map<String, String> _feedTypeLabels = {
  'offer': 'Angebot',
  'onePlusOneFree': '1+1 Gratis',
  'buyOneGetOneFree': 'Kauf 1, bekomme 1',
  'twoPlusOneFree': '2+1 Gratis',
  'buyTwoGetOneFree': 'Kauf 2, bekomme 1',
  'categoryDiscountPercent': 'Prozent-Rabatt',
  'categoryDiscountFixed': 'Rabatt',
  'happyHour': 'Happy Hour',
  'quickSell': 'Schnell weg',
  'rescueMe': 'Rette mich',
  'news': 'Neuigkeit',
  'newProduct': 'Neue Ware',
  'info': 'Info',
  'communityEvent': 'Event',
  'hiring': 'Team gesucht',
  'sponsoredSpot': 'Sponsored',
};

/// Beitragstypen als Filter-Optionen – NUR die Typen, die ein Merchant beim
/// Posten tatsächlich wählen kann (1:1 aus `_actionTypes`/`_postTypes` in
/// `merchantFeedCreatePage.dart` gespiegelt). Andere Werte in
/// [_feedTypeLabels] (z. B. `buyOneGetOneFree`, `sponsoredSpot`) sind
/// Alt-/Systemwerte, die kein Merchant mehr aktiv postet – als Filter-Option
/// wären sie meist leere Treffer, deshalb hier bewusst ausgeschlossen.
/// Reihenfolge: die 6 Aktions-/Deal-Typen zuerst (Angebot, Rabatt, Happy
/// Hour, 1+1, 2+1, Retter-Deal), dann die 5 allgemeinen Beitragstypen.
const List<String> feedPostTypeOptions = [
  'offer',
  'categoryDiscountPercent',
  'happyHour',
  'onePlusOneFree',
  'twoPlusOneFree',
  'rescueMe',
  'news',
  'newProduct',
  'info',
  'communityEvent',
  'hiring',
];
