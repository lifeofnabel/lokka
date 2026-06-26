/// Shortens long (Hessen) city names so wallet-card titles like
/// "Babel Imbiss – Frankfurt am Main" don't get truncated. The app is
/// Hessen-only, so this map covers the relevant cities; unknown names fall back
/// to stripping common suffixes ("… am Main", "… an der Lahn", "(Taunus)").
class HessenCity {
  const HessenCity._();

  static const String separator = '  –  ';

  static const Map<String, String> _short = {
    'frankfurt am main': 'FFM',
    'frankfurt': 'FFM',
    'wiesbaden': 'WI',
    'darmstadt': 'DA',
    'kassel': 'KS',
    'offenbach am main': 'OF',
    'offenbach': 'OF',
    'gießen': 'GI',
    'giessen': 'GI',
    'marburg an der lahn': 'MR',
    'marburg': 'MR',
    'fulda': 'FD',
    'hanau': 'HU',
    'rüsselsheim am main': 'RÜ',
    'rüsselsheim': 'RÜ',
    'bad homburg vor der höhe': 'HG',
    'bad homburg': 'HG',
    'wetzlar': 'WZ',
    'limburg an der lahn': 'LM',
    'limburg': 'LM',
    'oberursel (taunus)': 'OU',
    'oberursel': 'OU',
    'bad vilbel': 'BV',
    'bad nauheim': 'BN',
    'friedberg (hessen)': 'FB',
    'friedberg': 'FB',
    'neu-isenburg': 'NI',
    'dreieich': 'DI',
    'rodgau': 'RG',
    'maintal': 'MT',
    'langen': 'LAN',
  };

  /// The short form of a (Hessen) city, e.g. "Frankfurt am Main" → "FFM".
  static String shorten(String city) {
    final c = city.trim();
    if (c.isEmpty) return c;
    final mapped = _short[c.toLowerCase()];
    if (mapped != null) return mapped;
    // Generic fallback for unmapped cities: drop trailing "(…)" and suffixes.
    var out = c.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
    for (final suf in const [
      ' am Main',
      ' an der Lahn',
      ' an der Höhe',
      ' vor der Höhe',
      ' an der Bergstraße',
      ' im Taunus',
      ' am Taunus',
    ]) {
      if (out.toLowerCase().endsWith(suf.toLowerCase())) {
        out = out.substring(0, out.length - suf.length).trim();
        break;
      }
    }
    return out;
  }

  /// "Name – City", abbreviating the city only when the full title would be long
  /// enough to get truncated (so short titles keep the full city name).
  static String titleNameCity(String name, String city, {int maxLength = 22}) {
    final n = name.trim();
    final c = city.trim();
    if (c.isEmpty) return n.isEmpty ? 'Partner' : n;
    final full = '$n$separator$c';
    if (full.length <= maxLength) return full;
    final out = '$n$separator${shorten(c)}';
    return out.isEmpty ? 'Partner' : out;
  }
}
