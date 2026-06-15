import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
import '../../../core/theme/appSpacing.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';
import '../../merchant/tools/utils/linkOpener.dart';
import '../../merchant/tools/widgets/merchantToolUi.dart';
import '../models/supportTicketModel.dart';
import '../providers/supportProvider.dart';
import '../services/supportService.dart';

class MerchantSupportPage extends StatelessWidget {
  const MerchantSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SupportProvider(
        service: SupportService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantSupportView(),
    );
  }
}

class _MerchantSupportView extends StatelessWidget {
  const _MerchantSupportView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.support.title'),
      subtitle: texts.text('merchant.support.subtitle'),
      trailing: MerchantInfoTooltip(
        message: texts.text('merchant.support.subtitle'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: texts.text('merchant.support.newTicket'),
            icon: Icons.add_comment_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _openNewTicketSheet(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _openWhatsapp(texts),
            icon: const Icon(Icons.chat_rounded),
            label: Text(texts.text('merchant.support.whatsapp')),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards()
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else if (provider.tickets.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.support.emptyTitle'),
              message: texts.text('merchant.support.emptyMessage'),
              actionLabel: texts.text('merchant.support.newTicket'),
              onAction: () => _openNewTicketSheet(context),
            )
          else
            ...provider.tickets.map(
              (ticket) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TicketCard(ticket: ticket),
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: () => _openChatSheet(context, ticket),
      borderRadius: BorderRadius.circular(30),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MerchantPremiumColors.line),
              ),
              child: const Icon(Icons.support_agent_rounded, color: MerchantPremiumColors.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(ticket.type, texts),
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: MerchantPremiumColors.muted),
                  ),
                ],
              ),
            ),
            _StatusPill(label: _statusLabel(ticket.status, texts)),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Future<void> _openNewTicketSheet(BuildContext context) async {
  final parentContext = context;
  final provider = context.read<SupportProvider>();
  final texts = context.read<LanguageService>();
  final message = TextEditingController();
  var type = 'problem';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                texts.text('merchant.support.sheetTitle'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: InputDecoration(
                  labelText: texts.text('merchant.support.typeLabel'),
                ),
                items: _ticketTypes
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(_typeLabel(item, texts)),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => type = value ?? type),
              ),
              const SizedBox(height: AppSpacing.md),
              MerchantTextField(
                controller: message,
                label: texts.text('merchant.support.message'),
                maxLines: 5,
              ),
              const SizedBox(height: AppSpacing.md),
              MerchantPrimaryButton(
                label: texts.text('merchant.support.sendTicket'),
                onPressed: () async {
                  if (message.text.trim().isEmpty) return;
                  final ticketId = await provider.createTicket(type, message.text);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (ticketId != null && parentContext.mounted) {
                    final matches = provider.tickets.where((item) => item.ticketId == ticketId).toList();
                    if (matches.isNotEmpty) _openChatSheet(parentContext, matches.first);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  message.dispose();
}

Future<void> _openChatSheet(
  BuildContext context,
  SupportTicketModel ticket,
) async {
  final provider = context.read<SupportProvider>();
  final texts = context.read<LanguageService>();
  await provider.loadMessages(ticket.ticketId);
  if (!context.mounted) return;

  final text = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetContext) => ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<SupportProvider>(
        builder: (context, provider, _) {
          final messages = provider.messages[ticket.ticketId] ?? [];
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _typeLabel(ticket.type, texts),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: messages
                        .map(
                          (message) => Align(
                            alignment: message.senderRole == 'merchant' ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: message.senderRole == 'merchant'
                                    ? MerchantPremiumColors.ink
                                    : MerchantPremiumColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(18),
                                border: message.senderRole == 'merchant'
                                    ? null
                                    : Border.all(color: MerchantPremiumColors.line),
                              ),
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  color: message.senderRole == 'merchant'
                                      ? Colors.white
                                      : MerchantPremiumColors.ink,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: text,
                  label: texts.text('merchant.support.reply'),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: texts.text('merchant.support.send'),
                  icon: Icons.send_rounded,
                  isLoading: provider.isSaving,
                  onPressed: () async {
                    if (text.text.trim().isEmpty) return;
                    await provider.sendMessage(ticket.ticketId, text.text);
                    text.clear();
                  },
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  text.dispose();
}

Future<void> _openWhatsapp(LanguageService texts) {
  final text = Uri.encodeComponent(
    texts.text('merchant.support.whatsappText'),
  );
  return openExternalUrl('https://wa.me/491771816751?text=$text');
}

String _typeLabel(String type, LanguageService texts) {
  if (type == 'Problem' || type == 'problem') {
    return texts.text('merchant.support.type.problem');
  }
  if (type == 'Frage' || type == 'question') {
    return texts.text('merchant.support.type.question');
  }
  if (type == 'Rechnung' || type == 'billing') {
    return texts.text('merchant.support.type.billing');
  }
  if (type == 'Funktion wuenschen' ||
      type == 'Funktion wünschen' ||
      type == 'featureRequest') {
    return texts.text('merchant.support.type.featureRequest');
  }
  return type.isEmpty ? texts.text('merchant.support.title') : type;
}

String _statusLabel(String status, LanguageService texts) {
  return switch (status) {
    'inProgress' => texts.text('merchant.support.status.inProgress'),
    'closed' => texts.text('merchant.support.status.closed'),
    _ => texts.text('merchant.support.status.open'),
  };
}

const _ticketTypes = ['problem', 'question', 'billing', 'featureRequest'];
