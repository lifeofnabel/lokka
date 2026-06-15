import 'package:flutter/material.dart';

/// Berechnete Gamification-Kennzahlen (clientseitig aus Wallet-Daten).
class GamificationStats {
  const GamificationStats({
    required this.xp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.streakWeeks,
    required this.totalStamps,
    required this.redemptions,
    required this.walletPartners,
    required this.lifetimePoints,
  });

  final int xp;
  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int streakWeeks;
  final int totalStamps;
  final int redemptions;
  final int walletPartners;
  final int lifetimePoints;

  double get levelProgress =>
      xpForNextLevel > 0 ? (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0) : 0.0;

  static const empty = GamificationStats(
    xp: 0,
    level: 1,
    xpIntoLevel: 0,
    xpForNextLevel: 100,
    streakWeeks: 0,
    totalStamps: 0,
    redemptions: 0,
    walletPartners: 0,
    lifetimePoints: 0,
  );
}

class GamificationBadge {
  const GamificationBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int current;
  final int target;

  bool get earned => current >= target;
  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
}
