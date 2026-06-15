import 'dart:html' as html;

Future<bool> openExternalLink(String url) async {
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty) return false;
  html.window.open(cleanUrl, '_blank');
  return true;
}
