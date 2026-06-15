import 'package:share_plus/share_plus.dart';

/// Dünner Wrapper um share_plus (v13 API: SharePlus.instance.share).
class ShareUtils {
  const ShareUtils._();

  static Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  /// Teilt einen Feed-Beitrag als lesbaren Text.
  static Future<void> shareFeedPost({
    required String title,
    required String merchantName,
  }) async {
    final body = StringBuffer()..writeln(title);
    if (merchantName.trim().isNotEmpty) body.writeln('bei $merchantName');
    body
      ..writeln()
      ..write('Entdeckt mit Lokka');
    await shareText(body.toString().trim(), subject: title);
  }

  /// Teilt einen Partner/Shop als lesbaren Text.
  static Future<void> shareMerchant({
    required String shopName,
    String? area,
  }) async {
    final body = StringBuffer()..writeln(shopName);
    if (area != null && area.trim().isNotEmpty) body.writeln(area);
    body
      ..writeln()
      ..write('Entdeckt mit Lokka');
    await shareText(body.toString().trim(), subject: shopName);
  }
}
