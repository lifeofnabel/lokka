import 'package:flutter/material.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/gamification/models/gamificationModel.dart';

class UserGamificationService {
  const UserGamificationService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  Future<GamificationStats> loadStats() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return GamificationStats.empty;

    final results = await Future.wait([
      firestoreService.collection(FirebasePaths.userPointsProgress(uid)).get(),
      firestoreService.collection(FirebasePaths.userStampProgress(uid)).get(),
      firestoreService.collection(FirebasePaths.userWalletCards(uid)).get(),
    ]);

    var lifetimePoints = 0;
    for (final d in results[0].docs) {
      lifetimePoints += (d.data()['lifetimePoints'] as num?)?.toInt() ?? 0;
    }

    var totalStamps = 0;
    var redemptions = 0;
    final activity = <DateTime>[];
    for (final d in results[1].docs) {
      final data = d.data();
      totalStamps += (data['currentStamps'] as num?)?.toInt() ?? 0;
      final claimedAt = _date(data['claimedAt']);
      if (claimedAt != null || (data['status'] as String?) == 'claimed') {
        redemptions++;
      }
      if (claimedAt != null) activity.add(claimedAt);
      final lastStampAt = _date(data['lastStampAt']);
      if (lastStampAt != null) activity.add(lastStampAt);
    }

    for (final d in results[2].docs) {
      final joined = _date(d.data()['joinedAt']);
      if (joined != null) activity.add(joined);
    }
    final walletPartners = results[2].docs.length;

    final xp = lifetimePoints +
        totalStamps * 10 +
        redemptions * 50 +
        walletPartners * 20;
    final level = _levelForXp(xp);
    final base = _xpForLevel(level);
    final next = _xpForLevel(level + 1);

    return GamificationStats(
      xp: xp,
      level: level,
      xpIntoLevel: xp - base,
      xpForNextLevel: next - base,
      streakWeeks: _streakWeeks(activity),
      totalStamps: totalStamps,
      redemptions: redemptions,
      walletPartners: walletPartners,
      lifetimePoints: lifetimePoints,
    );
  }

  List<GamificationBadge> badgesFor(GamificationStats s) {
    return [
      GamificationBadge(
        id: 'first_stamp',
        title: 'Erster Stempel',
        description: 'Sammle deinen ersten Stempel',
        icon: Icons.local_activity_rounded,
        current: s.totalStamps,
        target: 1,
      ),
      GamificationBadge(
        id: 'collector',
        title: 'Sammler',
        description: '25 Stempel gesammelt',
        icon: Icons.loyalty_rounded,
        current: s.totalStamps,
        target: 25,
      ),
      GamificationBadge(
        id: 'regular',
        title: 'Stammkunde',
        description: '5 Belohnungen eingelöst',
        icon: Icons.redeem_rounded,
        current: s.redemptions,
        target: 5,
      ),
      GamificationBadge(
        id: 'explorer',
        title: 'Entdecker',
        description: '10 Partner in der Wallet',
        icon: Icons.explore_rounded,
        current: s.walletPartners,
        target: 10,
      ),
      GamificationBadge(
        id: 'streak',
        title: 'Dranbleiber',
        description: '4 Wochen Streak',
        icon: Icons.local_fire_department_rounded,
        current: s.streakWeeks,
        target: 4,
      ),
      GamificationBadge(
        id: 'level5',
        title: 'Aufsteiger',
        description: 'Erreiche Level 5',
        icon: Icons.military_tech_rounded,
        current: s.level,
        target: 5,
      ),
      GamificationBadge(
        id: 'points1000',
        title: 'Punktejäger',
        description: '1000 Lifetime-Punkte',
        icon: Icons.stars_rounded,
        current: s.lifetimePoints,
        target: 1000,
      ),
    ];
  }

  int _levelForXp(int xp) {
    var level = 1;
    while (level < 99 && xp >= _xpForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  // Level n wird bei (n-1)^2 * 100 XP erreicht (sanft steigende Kurve).
  int _xpForLevel(int level) => (level - 1) * (level - 1) * 100;

  int _streakWeeks(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    final weeks = dates.map(_weekIndex).toSet();
    var w = _weekIndex(DateTime.now());
    if (!weeks.contains(w)) {
      w -= 1; // aktuelle Woche darf noch leer sein
      if (!weeks.contains(w)) return 0;
    }
    var streak = 0;
    while (weeks.contains(w)) {
      streak++;
      w--;
    }
    return streak;
  }

  int _weekIndex(DateTime d) {
    final epoch = DateTime(2020, 1, 6); // ein Montag
    return (d.difference(epoch).inDays / 7).floor();
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(v.toString());
    }
  }
}
