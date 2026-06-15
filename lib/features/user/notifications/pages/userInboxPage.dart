import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/notifications/models/userNotificationModel.dart';
import 'package:lokka/features/user/notifications/services/userNotificationService.dart';

class UserInboxPage extends StatefulWidget {
  const UserInboxPage({super.key});

  @override
  State<UserInboxPage> createState() => _UserInboxPageState();
}

class _UserInboxPageState extends State<UserInboxPage> {
  late final UserNotificationService _service;

  @override
  void initState() {
    super.initState();
    _service = UserNotificationService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
    );
  }

  Future<void> _markAllRead() async {
    final items = await _service.notificationsStream().first;
    await _service.markAllRead(items.where((n) => !n.read).map((n) => n.id));
  }

  void _onTap(UserNotificationModel n) {
    _service.markRead(n.id);
    final route = n.route;
    final router = GoRouter.of(context);
    Navigator.pop(context);
    if (route != null && route.isNotEmpty) router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Benachrichtigungen',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Alle gelesen'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: StreamBuilder<List<UserNotificationModel>>(
        stream: _service.notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }
          if (snapshot.hasError) {
            return const AppErrorState(
              message: 'Benachrichtigungen konnten nicht geladen werden',
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Keine Benachrichtigungen',
              message:
                  'Hier erscheinen Hinweise zu deinen Partnern, Stempeln und Coupons.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _NotificationTile(
              notification: items[i],
              onTap: () => _onTap(items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final UserNotificationModel notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
        'stamp' => Icons.loyalty_rounded,
        'coupon' => Icons.local_offer_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _accent(ColorScheme cs) => switch (notification.type) {
        'stamp' => cs.primary,
        'coupon' => AppColors.googleBlue,
        _ => cs.onSurfaceVariant,
      };

  String _fmt(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    if (diff.inDays == 1) return 'gestern';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unread = !notification.read;
    final accent = _accent(cs);
    return Material(
      color: unread ? cs.secondaryContainer : AppColors.surfaceGray,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 22, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            margin: const EdgeInsets.only(top: 6, left: 8),
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _fmt(notification.createdAt),
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
