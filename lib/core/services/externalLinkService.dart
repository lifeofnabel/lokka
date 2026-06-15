import 'externalLinkServiceStub.dart'
    if (dart.library.html) 'externalLinkServiceWeb.dart';

class ExternalLinkService {
  const ExternalLinkService._();

  static Future<bool> openInNewTab(String url) {
    return openExternalLink(url);
  }
}
