import 'package:flutter/foundation.dart';

import '../models/supportTicketModel.dart';
import '../services/supportService.dart';

class SupportProvider extends ChangeNotifier {
  SupportProvider({required this.service});

  final SupportService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<SupportTicketModel> tickets = [];
  Map<String, List<SupportMessageModel>> messages = {};

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      tickets = await service.loadTickets();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createTicket(String type, String message) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final ticketId = await service.createTicket(type: type, message: message);
      tickets = await service.loadTickets();
      return ticketId;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String ticketId) async {
    try {
      messages = {
        ...messages,
        ticketId: await service.loadMessages(ticketId),
      };
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendMessage(String ticketId, String text) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await service.sendMessage(ticketId: ticketId, text: text);
      messages = {
        ...messages,
        ticketId: await service.loadMessages(ticketId),
      };
      tickets = await service.loadTickets();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
