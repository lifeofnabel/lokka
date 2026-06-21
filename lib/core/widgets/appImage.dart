import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ??
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined),
          );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      errorWidget: (_, _, _) =>
          errorWidget ?? const Icon(Icons.broken_image_outlined),
      placeholder: (_, _) =>
          placeholder ?? const Center(child: CircularProgressIndicator()),
    );
  }
}
