import 'package:flutter/material.dart';

import '../../../../core/theme/appColors.dart';
import '../models/display_block.dart';
import '../models/display_layout.dart';

/// A self-contained widget that renders a TV-poster style preview of a layout.
/// Not pixel-perfect — communicates structure and content clearly.
class LayoutPreviewWidget extends StatelessWidget {
  const LayoutPreviewWidget({
    super.key,
    required this.layout,
    required this.blocks,
    this.width,
    this.height,
  });

  final DisplayLayout layout;
  final List<DisplayBlock> blocks;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isPortrait = layout.orientation == DisplayOrientation.portrait;
    final isDark = layout.backgroundStyle != 'light';

    final bg = isDark
        ? const Color(0xFF0F1410)
        : const Color(0xFFF5F6F2);
    final fg = isDark ? AppColors.white : AppColors.black;

    final visibleBlocks = blocks.where((b) => b.isVisible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return AspectRatio(
      aspectRatio: isPortrait ? 9 / 16 : 16 / 9,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Background image (first image block, if backgroundStyle == 'image')
            if (layout.backgroundStyle == 'image')
              _buildBgImage(visibleBlocks),

            // Dark overlay
            if (isDark)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(30),
                        Colors.black.withAlpha(150),
                      ],
                    ),
                  ),
                ),
              ),

            // Block content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: visibleBlocks
                    .where((b) => b.type != DisplayBlockType.image ||
                        layout.backgroundStyle != 'image')
                    .map((b) => _buildBlock(b, fg))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBgImage(List<DisplayBlock> blocks) {
    final imgBlock = blocks
        .where((b) => b.type == DisplayBlockType.image)
        .firstOrNull;
    final url = imgBlock?.value['url'] as String? ?? '';
    if (url.isEmpty) {
      return Positioned.fill(
        child: ColoredBox(color: const Color(0xFF1A2020)),
      );
    }
    return Positioned.fill(
      child: Image.network(url, fit: BoxFit.cover),
    );
  }

  Widget _buildBlock(DisplayBlock block, Color defaultFg) {
    switch (block.type) {
      case DisplayBlockType.text:
        final content = block.value['content'] as String? ?? '';
        if (content.isEmpty) return const SizedBox.shrink();
        final size = (block.value['fontSize'] as num?)?.toDouble() ?? 16.0;
        final clampedSize = size.clamp(8.0, 28.0);
        final colorHex = block.value['color'] as String? ?? '#FFFFFF';
        final align = block.value['alignment'] as String? ?? 'center';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            content,
            textAlign: _textAlign(align),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: clampedSize,
              fontWeight: FontWeight.w800,
              color: _hexColor(colorHex, defaultFg),
            ),
          ),
        );

      case DisplayBlockType.price:
        final price = block.value['price'] as String? ?? '';
        final oldPrice = block.value['oldPrice'] as String? ?? '';
        final currency = block.value['currency'] as String? ?? '€';
        if (price.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$price $currency',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (oldPrice.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '$oldPrice $currency',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        );

      case DisplayBlockType.image:
        final url = block.value['url'] as String? ?? '';
        return Container(
          height: 70,
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3030),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isEmpty
              ? const Center(
                  child: Icon(Icons.image_rounded, color: Color(0xFF4A5555), size: 28))
              : Image.network(url, fit: BoxFit.cover, width: double.infinity),
        );

      case DisplayBlockType.qr:
        final label = block.value['label'] as String? ?? 'Scannen';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.qr_code_2_rounded, size: 24, color: Colors.black),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
            ],
          ),
        );

      case DisplayBlockType.badge:
        final text = block.value['text'] as String? ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        final bgHex = block.value['backgroundColor'] as String? ?? '#FF3B30';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _hexColor(bgHex, Colors.red),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
        );

      case DisplayBlockType.menuList:
        final items = block.value['items'] as List? ?? [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('(Menüliste leer)',
                style: TextStyle(fontSize: 10, color: defaultFg.withAlpha(100))),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.take(3).map((item) {
            final map = item as Map?;
            final name = map?['name']?.toString() ?? '';
            final price = map?['price']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 10, color: Colors.white70))),
                  Text(price, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            );
          }).toList(),
        );

      case DisplayBlockType.gallery:
        final urls = block.value['urls'] as List? ?? [];
        return Container(
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3030),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_library_rounded, color: Color(0xFF4A5555), size: 20),
                const SizedBox(width: 6),
                Text('${urls.length} Bilder',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6A7575))),
              ],
            ),
          ),
        );

      case DisplayBlockType.loyalty:
        final title = block.value['title'] as String? ?? '';
        final reward = block.value['rewardText'] as String? ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              if (title.isNotEmpty)
                Text(title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
              if (reward.isNotEmpty)
                Text(reward,
                    style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        );

      case DisplayBlockType.review:
        final text = block.value['text'] as String? ?? '';
        final author = block.value['authorName'] as String? ?? '';
        final rating = (block.value['rating'] as num?)?.toInt() ?? 5;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              Text('⭐' * rating.clamp(0, 5),
                  style: const TextStyle(fontSize: 10)),
              if (text.isNotEmpty)
                Text('"$text"',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.white70)),
              if (author.isNotEmpty)
                Text('– $author',
                    style: const TextStyle(fontSize: 9, color: Colors.white54)),
            ],
          ),
        );

      case DisplayBlockType.divider:
        final opacity = (block.value['opacity'] as num?)?.toDouble() ?? 0.3;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withAlpha((opacity * 255).toInt())),
        );

      case DisplayBlockType.spacer:
        final height = (block.value['height'] as num?)?.toDouble() ?? 8.0;
        return SizedBox(height: height.clamp(4.0, 32.0));
    }
  }

  TextAlign _textAlign(String align) {
    switch (align) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }

  Color _hexColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}
