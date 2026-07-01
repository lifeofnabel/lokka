import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/legalService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';

/// In-app privacy policy page. Reads the content from Firestore
/// (`legal/privacyPolicy`) via [LegalService], falling back to the bundled
/// asset. Replaces the previous external-URL launch.
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        LegalService(context.read<FirestoreService>()).loadPrivacyPolicy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(title: const Text('Datenschutzerklärung')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState();
          }
          final data = snapshot.data;
          if (data == null || data['sections'] is! List) {
            return const AppErrorState(
              message: 'Datenschutzerklärung konnte nicht geladen werden.',
            );
          }
          return _PolicyBody(data: data);
        },
      ),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  const _PolicyBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = (data['title'] as String?) ?? 'Datenschutzerklärung';
    final updated = (data['updated'] as String?) ?? '';
    final intro = (data['intro'] as String?) ?? '';
    final sections = (data['sections'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (updated.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Stand: $updated',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
          if (intro.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: Text(
                intro,
                style: tt.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final s in sections) ...[
            Text(
              (s['heading'] as String?) ?? '',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (s['body'] as String?) ?? '',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
