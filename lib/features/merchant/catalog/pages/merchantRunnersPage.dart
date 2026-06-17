import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

/// „Runner" – erreichbar über die Speisekarte-Seite (nur im Runner-Modus).
/// Servicekräfte mit Namen anlegen und auf verfügbar/nicht verfügbar stellen;
/// im Shop wird beim Betreten direkt gewählt, wer gerade bedient (kein PIN).
class MerchantRunnersPage extends StatelessWidget {
  const MerchantRunnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantRunnersProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantRunnersView(),
    );
  }
}

class _MerchantRunnersView extends StatelessWidget {
  const _MerchantRunnersView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantRunnersProvider>();
    return MerchantToolScaffold(
      title: texts.text('merchant.runners.title'),
      subtitle: texts.text('merchant.runners.subtitle'),
      backPath: '/merchant/catalog',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.runners.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: texts.text('merchant.runners.add'),
            icon: Icons.person_add_alt_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _openRunnerSheet(context),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards(count: 3)
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else if (provider.runners.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.runners.emptyTitle'),
              message: texts.text('merchant.runners.emptyMessage'),
              actionLabel: texts.text('merchant.runners.add'),
              onAction: () => _openRunnerSheet(context),
            )
          else
            ...provider.runners.map(
              (runner) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RunnerTile(runner: runner),
              ),
            ),
        ],
      ),
    );
  }
}

class _RunnerTile extends StatelessWidget {
  const _RunnerTile({required this.runner});

  final RunnerData runner;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.read<MerchantRunnersProvider>();
    return MerchantPremiumCard(
      onTap: () => _openRunnerSheet(context, runner: runner),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const MerchantPremiumIconBox(icon: Icons.directions_run_rounded),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  runner.name.isEmpty ? '–' : runner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texts.text(runner.available
                      ? 'merchant.runners.available'
                      : 'merchant.runners.unavailable'),
                  style: TextStyle(
                    color: runner.available
                        ? MerchantPremiumColors.success
                        : MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          // Verfügbar/nicht verfügbar direkt umschalten.
          Switch(
            value: runner.available,
            activeThumbColor: MerchantPremiumColors.gold,
            onChanged: (value) => provider.setAvailable(runner.id, value),
          ),
          IconButton(
            tooltip: texts.text('common.delete'),
            onPressed: () => provider.deleteRunner(runner.id),
            icon: const Icon(Icons.delete_outline_rounded,
                color: MerchantPremiumColors.danger),
          ),
        ],
      ),
    );
  }
}

Future<void> _openRunnerSheet(BuildContext context, {RunnerData? runner}) async {
  final provider = context.read<MerchantRunnersProvider>();
  final texts = context.read<LanguageService>();
  final name = TextEditingController(text: runner?.name ?? '');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.text(runner == null ? 'merchant.runners.add' : 'merchant.runners.edit'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(controller: name, label: texts.text('merchant.runners.name')),
          const SizedBox(height: AppSpacing.lg),
          MerchantPrimaryButton(
            label: texts.text('common.save'),
            icon: Icons.save_rounded,
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(texts.text('merchant.runners.error.name'))),
                );
                return;
              }
              if (runner == null) {
                await provider.addRunner(name.text);
              } else {
                await provider.renameRunner(runner.id, name.text);
              }
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    ),
  );
  name.dispose();
}
