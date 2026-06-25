import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';

enum _ProtocolType { like, stamp, points, walletJoin }

class _ProtocolEntry {
  const _ProtocolEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  final _ProtocolType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
}

class MeinProtokollPage extends StatefulWidget {
  const MeinProtokollPage({super.key});

  @override
  State<MeinProtokollPage> createState() => _MeinProtokollPageState();
}

class _MeinProtokollPageState extends State<MeinProtokollPage> {
  late final FirestoreService _firestoreService;
  late final AuthService _authService;

  List<_ProtocolEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _authService = context.read<AuthService>();
    _load();
  }

  Future<void> _load() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final results = await Future.wait([
        _firestoreService
            .collection(FirebasePaths.userLikedPosts(uid))
            .orderBy('likedAt', descending: true)
            .limit(30)
            .get(),
        _firestoreService
            .collection(FirebasePaths.userStampProgress(uid))
            .orderBy('updatedAt', descending: true)
            .limit(30)
            .get(),
        _firestoreService
            .collection(FirebasePaths.userWalletCards(uid))
            .orderBy('joinedAt', descending: true)
            .limit(30)
            .get(),
      ]);

      final entries = <_ProtocolEntry>[];

      for (final doc in results[0].docs) {
        final ts = _parseDate(doc.data()['likedAt']);
        if (ts != null) {
          // No raw post-id here — that meant nothing to a normal user.
          entries.add(_ProtocolEntry(
            type: _ProtocolType.like,
            title: 'Beitrag gefällt dir',
            subtitle: '',
            timestamp: ts,
          ));
        }
      }

      for (final doc in results[1].docs) {
        final ts = _parseDate(doc.data()['updatedAt']);
        final stamps = doc.data()['currentStamps'] as int? ?? 0;
        // Only show it as "collected" once there is actually a stamp — a fresh
        // card at 0 isn't an activity worth listing.
        if (ts != null && stamps > 0) {
          final shop = _shopName(doc.data()['merchantName']);
          entries.add(_ProtocolEntry(
            type: _ProtocolType.stamp,
            title: 'Stempel gesammelt',
            subtitle: '$stamps Stempel bei $shop',
            timestamp: ts,
          ));
        }
      }

      for (final doc in results[2].docs) {
        final ts = _parseDate(doc.data()['joinedAt']);
        if (ts != null) {
          entries.add(_ProtocolEntry(
            type: _ProtocolType.walletJoin,
            title: 'Laden gefolgt',
            subtitle: _shopName(doc.data()['merchantName']),
            timestamp: ts,
          ));
        }
      }

      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Plain shop name, with a friendly fallback (never a raw id or "Händler").
  String _shopName(dynamic value) {
    final name = (value as String?)?.trim() ?? '';
    return name.isEmpty ? 'einem Laden' : name;
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(v.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Meine Aktivitäten'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'Noch nichts los',
        message: 'Sobald du Beiträge likest, Stempel sammelst oder Läden folgst, '
            'siehst du hier deine letzten Aktivitäten.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _EntryTile(entry: _entries[i]),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final _ProtocolEntry entry;

  IconData get _icon => switch (entry.type) {
        _ProtocolType.like => Icons.favorite_rounded,
        _ProtocolType.stamp => Icons.loyalty_rounded,
        _ProtocolType.points => Icons.stars_rounded,
        _ProtocolType.walletJoin => Icons.wallet_rounded,
      };

  Color _color(ColorScheme cs) => switch (entry.type) {
        _ProtocolType.like => cs.error,
        _ProtocolType.stamp => cs.primary,
        _ProtocolType.points => AppColors.googleYellow,
        _ProtocolType.walletJoin => AppColors.googleBlue,
      };

  String _fmt(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Heute';
    if (diff == 1) return 'Gestern';
    if (diff < 7) return 'vor $diff Tagen';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _color(cs);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (entry.subtitle.isNotEmpty)
                  Text(
                    entry.subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            _fmt(entry.timestamp),
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
