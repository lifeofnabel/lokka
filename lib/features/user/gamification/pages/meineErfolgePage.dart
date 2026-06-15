import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/gamification/models/gamificationModel.dart';
import 'package:lokka/features/user/gamification/services/userGamificationService.dart';
import 'package:lokka/features/user/gamification/widgets/celebration.dart';

class MeineErfolgePage extends StatefulWidget {
  const MeineErfolgePage({super.key});

  @override
  State<MeineErfolgePage> createState() => _MeineErfolgePageState();
}

class _MeineErfolgePageState extends State<MeineErfolgePage> {
  static const _lastLevelKey = 'gamification.lastSeenLevel';

  late final UserGamificationService _service;
  late final LocalCacheService _cache;

  GamificationStats _stats = GamificationStats.empty;
  List<GamificationBadge> _badges = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = UserGamificationService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
    );
    _cache = context.read<LocalCacheService>();
    _load();
  }

  Future<void> _load() async {
    final stats = await _service.loadStats();
    final badges = _service.badgesFor(stats);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _badges = badges;
      _loading = false;
    });
    await _maybeCelebrateLevelUp(stats.level);
  }

  Future<void> _maybeCelebrateLevelUp(int level) async {
    final m = await _cache.readMap(_lastLevelKey,
        ttl: const Duration(days: 365000));
    final last = (m?['value'] as num?)?.toInt();
    await _cache.writeMap(_lastLevelKey, {'value': level});
    if (last != null && level > last && mounted) {
      await Celebration.maybeShow(
        context,
        _cache,
        title: 'Level $level erreicht!',
        subtitle: 'Weiter so!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final earned = _badges.where((b) => b.earned).toList();
    final inProgress = _badges.where((b) => !b.earned).toList();
    final ordered = [...earned, ...inProgress];

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Meine Erfolge',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const AppLoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
              children: [
                _LevelHeader(stats: _stats),
                const SizedBox(height: AppSpacing.lg),
                _StatsRow(stats: _stats),
                if (ordered.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Text(
                      'Abzeichen',
                      style:
                          tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: ordered.length,
                    itemBuilder: (_, i) => _BadgeCard(badge: ordered[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.stats});

  final GamificationStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.military_tech_rounded,
                    color: cs.onPrimary, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${stats.level}',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      '${stats.xp} XP gesamt',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSecondaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (stats.streakWeeks > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AppColors.googleYellow, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        '${stats.streakWeeks} Wo.',
                        style: tt.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: stats.levelProgress,
              minHeight: 10,
              backgroundColor: cs.onSecondaryContainer.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Noch ${stats.xpForNextLevel - stats.xpIntoLevel} XP bis Level ${stats.level + 1}',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSecondaryContainer.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final GamificationStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat('Stempel', '${stats.totalStamps}', Icons.loyalty_rounded),
        const SizedBox(width: AppSpacing.md),
        _stat('Einlösungen', '${stats.redemptions}', Icons.redeem_rounded),
        const SizedBox(width: AppSpacing.md),
        _stat('Partner', '${stats.walletPartners}', Icons.store_rounded),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(icon, color: cs.primary, size: 24),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  value,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final GamificationBadge badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final earned = badge.earned;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: earned ? cs.secondaryContainer : AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: earned ? cs.primary : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(badge.icon,
                    size: 22,
                    color: earned ? cs.onPrimary : cs.onSurfaceVariant),
              ),
              const Spacer(),
              if (earned)
                Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            badge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: earned ? cs.onSecondaryContainer : cs.onSurface,
            ),
          ),
          const Spacer(),
          if (!earned) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: badge.progress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${badge.current} / ${badge.target}',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
