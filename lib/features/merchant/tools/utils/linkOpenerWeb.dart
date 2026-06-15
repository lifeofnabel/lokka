import 'dart:html' as html;

Future<void> openExternalUrl(String url) async {
  html.window.open(url, '_blank');
}
