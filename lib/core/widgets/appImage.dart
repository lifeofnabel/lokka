import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Robuste Netzwerk-Bildanzeige.
///
/// Im **Web** wird bewusst `Image.network` (nativer Browser-Decode über ein
/// `<img>`-Element) genutzt statt `cached_network_image`. Letzteres lädt die
/// Bytes per XHR und dekodiert sie über CanvasKit – das scheitert im Web bei
/// vielen (gültigen) JPEGs mit „EncodingError: The source image cannot be
/// decoded". Der native Pfad ist deutlich toleranter und zeigt Firebase-
/// Storage-Bilder zuverlässig an.
///
/// Auf **Mobile** bleibt `cached_network_image` (Disk-Cache, schnelleres
/// Scrollen) erhalten.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;

  /// Optionale Decode-Breite (in px) zur Begrenzung des im Speicher gehaltenen
  /// Bitmaps. Sollte etwa der tatsächlichen Anzeigebreite entsprechen
  /// (DevicePixelRatio einkalkuliert), um Speicher zu sparen.
  final int? memCacheWidth;

  /// Optionaler Platzhalter, der den Standard-Spinner ersetzt.
  final Widget? placeholder;

  /// Optionales Fehler-Widget, das den Standard-Bruchbild-Icon ersetzt.
  final Widget? errorWidget;

  Widget get _errorFallback =>
      errorWidget ?? const Icon(Icons.broken_image_outlined);

  Widget get _loadingFallback =>
      placeholder ?? const Center(child: CircularProgressIndicator());

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    // Leere oder offensichtlich ungültige (nicht-http) URLs gar nicht erst laden.
    if (url.isEmpty || !url.startsWith('http')) {
      if (url.isNotEmpty) {
        debugPrint('[IMG] ungültige Bild-URL (kein http): "$url"');
      }
      return errorWidget ??
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined),
          );
    }

    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        cacheWidth: memCacheWidth,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[IMG] lädt nicht (web): $url -> $error');
          return _errorFallback;
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _loadingFallback;
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: memCacheWidth,
      errorWidget: (_, failedUrl, error) {
        debugPrint('[IMG] lädt nicht: $failedUrl -> $error');
        return _errorFallback;
      },
      placeholder: (_, _) => _loadingFallback,
    );
  }
}
