import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/utils/linkOpener.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantSupportPage extends StatelessWidget {
  const MerchantSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantSupportProvider(
        service: MerchantToolsService(
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
    final provider = context.watch<MerchantSupportProvider>();
    return MerchantToolScaffold(
      title: 'Support',
      subtitle: 'Schreib uns, wenn etwas nicht funktioniert oder du Hilfe brauchst.',
      trailing: const MerchantInfoTooltip(message: 'Schreib uns, wenn etwas nicht funktioniert oder du Hilfe brauchst.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: 'Neue Anfrage',
            icon: Icons.add_comment_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _openNewTicketSheet(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _openWhatsapp(),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('WhatsApp Support'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards()
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else if (provider.tickets.isEmpty)
            MerchantEmptyState(
              title: 'Noch keine Anfragen',
              message: 'Wenn du Hilfe brauchst, erstelle eine kurze Anfrage oder schreibe uns per WhatsApp.',
              actionLabel: 'Neue Anfrage',
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

  final SupportTicketData ticket;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openChatSheet(context, ticket),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.support_agent_rounded),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_typeLabel(ticket.type), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(ticket.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gray700)),
                ],
              ),
            ),
            _StatusPill(label: _statusLabel(ticket.status)),
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
      decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

Future<void> _openNewTicketSheet(BuildContext context) async {
  final parentContext = context;
  final provider = context.read<MerchantSupportProvider>();
  final message = TextEditingController();
  var type = 'Problem';

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
              const Text('Wie koennen wir helfen?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Art der Anfrage'),
                items: _ticketTypes.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) => setState(() => type = value ?? type),
              ),
              const SizedBox(height: AppSpacing.md),
              MerchantTextField(controller: message, label: 'Nachricht', maxLines: 5),
              const SizedBox(height: AppSpacing.md),
              MerchantPrimaryButton(
                label: 'Anfrage senden',
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
}

Future<void> _openChatSheet(BuildContext context, SupportTicketData ticket) async {
  final provider = context.read<MerchantSupportProvider>();
  await provider.loadMessages(ticket.ticketId);
  if (!context.mounted) return;

  final text = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetContext) => Consumer<MerchantSupportProvider>(
      builder: (context, provider, _) {
        final messages = provider.messages[ticket.ticketId] ?? [];
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_typeLabel(ticket.type), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
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
                              color: message.senderRole == 'merchant' ? AppColors.black : AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(color: message.senderRole == 'merchant' ? AppColors.white : AppColors.black),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              MerchantTextField(controller: text, label: 'Antwort schreiben', maxLines: 3),
              const SizedBox(height: AppSpacing.md),
              MerchantPrimaryButton(
                label: 'Senden',
                icon: Icons.send_rounded,
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
  );
}

Future<void> _openWhatsapp() {
  final text = Uri.encodeComponent('Hallo Lokka, ich brauche Hilfe zu meinem Geschaeftskonto ...');
  return openExternalUrl('https://wa.me/491771816751?text=$text');
}

String _typeLabel(String type) => type.isEmpty ? 'Support' : type;

String _statusLabel(String status) {
  return switch (status) {
    'inProgress' => 'In Arbeit',
    'closed' => 'Geschlossen',
    _ => 'Offen',
  };
}

const _ticketTypes = ['Problem', 'Frage', 'Rechnung', 'Funktion wuenschen'];
