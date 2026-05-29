import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';

class FeedActionButtons extends StatelessWidget {
  const FeedActionButtons({
    super.key,
    required this.likesCount,
    required this.isLiked,
    required this.onLike,
    this.onShare,
  });

  final int likesCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: '$likesCount',
          color: isLiked ? Colors.redAccent : AppColors.gray500,
          onTap: onLike,
        ),
        const SizedBox(width: 16),
        if (onShare != null)
          _ActionBtn(
            icon: Icons.ios_share_rounded,
            label: 'Teilen',
            color: AppColors.gray500,
            onTap: onShare!,
          ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
