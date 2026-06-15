import '../../../../core/services/languageService.dart';

/// Geteilte Formatierungen/Berechnungen für den Merchant-Feed (Preise, Rabatt,
/// Initialen). Aus merchantFeedCreatePage.dart ausgelagert (#16), damit die Page
/// UND die ausgelagerte Vorschau (merchantFeedPostPreview.dart) dieselbe Logik
/// nutzen statt sie zu duplizieren.

num? feedParseNumber(String value) {
  final clean = value.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return num.tryParse(clean);
}

int? feedDiscountPercent(String oldPrice, String newPrice) {
  final oldValue = feedParseNumber(oldPrice);
  final newValue = feedParseNumber(newPrice);
  if (oldValue == null || newValue == null || oldValue <= 0 || newValue >= oldValue) {
    return null;
  }
  return (((oldValue - newValue) / oldValue) * 100).round();
}

String feedNormalizePrice(String value) {
  final number = feedParseNumber(value);
  if (number == null) return '';
  return '${number.toStringAsFixed(number % 1 == 0 ? 0 : 2).replaceAll('.', ',')} €';
}

String feedDiscountLabel(String oldPrice, String newPrice, LanguageService texts) {
  final discount = feedDiscountPercent(oldPrice, newPrice);
  if (discount != null && discount > 0) return '-$discount%';
  final newValue = feedNormalizePrice(newPrice);
  return newValue.isEmpty
      ? ''
      : texts.text('merchant.feedCreate.priceBadge').replaceAll('{price}', newValue);
}

String feedInitials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'L';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
