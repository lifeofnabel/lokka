import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';

Future<Uint8List?> showSquareImageCropSheet({
  required BuildContext context,
  required Uint8List imageBytes,
}) {
  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SquareImageCropSheet(imageBytes: imageBytes),
  );
}

class _SquareImageCropSheet extends StatefulWidget {
  const _SquareImageCropSheet({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_SquareImageCropSheet> createState() => _SquareImageCropSheetState();
}

class _SquareImageCropSheetState extends State<_SquareImageCropSheet> {
  final _controller = CropController();
  bool _isCropping = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(34),
          boxShadow: MerchantPremiumShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MerchantPremiumIconBox(icon: Icons.crop_rounded),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        texts.text('merchant.feedCreate.cropTitle'),
                        style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        texts.text('merchant.feedCreate.cropTip'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MerchantPremiumColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: AspectRatio(
                aspectRatio: 1,
                child: Crop(
                  image: widget.imageBytes,
                  controller: _controller,
                  aspectRatio: 1,
                  onCropped: (result) {
                    if (result is CropSuccess) {
                      Navigator.of(context).pop(result.croppedImage);
                      return;
                    }
                    if (result is CropFailure) {
                      setState(() {
                        _isCropping = false;
                        _error = result.cause.toString();
                      });
                    }
                  },
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                texts.text('merchant.feedCreate.cropFailed'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPremiumColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            MerchantPrimaryButton(
              label: texts.text('merchant.feedCreate.cropSave'),
              icon: Icons.check_rounded,
              isLoading: _isCropping,
              onPressed: () {
                setState(() {
                  _isCropping = true;
                  _error = null;
                });
                _controller.crop();
              },
            ),
            TextButton(
              onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
              child: Text(texts.text('common.cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
