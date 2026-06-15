import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebasePaths.dart';
import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../models/supportTicketModel.dart';

class SupportService {
  const SupportService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw StateError('auth.error.signInAgain');
    }
    return uid;
  }

  Future<Map<String, dynamic>?> loadMerchant() {
    return firestoreService.getMerchantProfile(merchantId);
  }

  Future<List<SupportTicketModel>> loadTickets() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.supportTickets)
        .where('merchantId', isEqualTo: merchantId)
        .get();
    final tickets = snapshot.docs
        .map((doc) => SupportTicketModel.fromMap({
              'ticketId': doc.id,
              ...doc.data(),
            }))
        .toList();
    tickets.sort((a, b) => (b.lastMessageAt ?? b.createdAt ?? DateTime(0))
        .compareTo(a.lastMessageAt ?? a.createdAt ?? DateTime(0)));
    return tickets;
  }

  Future<String> createTicket({
    required String type,
    required String message,
  }) async {
    final merchant = await loadMerchant() ?? {};
    final ticketId =
        firestoreService.collection(FirebasePaths.supportTickets).doc().id;
    await firestoreService.setDocument(FirebasePaths.supportTicket(ticketId), {
      'ticketId': ticketId,
      'merchantId': merchantId,
      'merchantName': merchant['shopName'] ?? '',
      'merchantEmail': merchant['email'] ?? authService.currentUser?.email ?? '',
      'type': type,
      'message': message.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await sendMessage(ticketId: ticketId, text: message);
    return ticketId;
  }

  Future<List<SupportMessageModel>> loadMessages(String ticketId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.supportMessages(ticketId))
        .get();
    final messages = snapshot.docs
        .map((doc) => SupportMessageModel.fromMap({
              'messageId': doc.id,
              ...doc.data(),
            }))
        .toList();
    messages.sort((a, b) =>
        (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return messages;
  }

  Future<void> sendMessage({
    required String ticketId,
    required String text,
  }) async {
    final messageId =
        firestoreService.collection(FirebasePaths.supportMessages(ticketId)).doc().id;
    await firestoreService.setDocument(
      FirebasePaths.supportMessage(ticketId, messageId),
      {
        'messageId': messageId,
        'senderRole': 'merchant',
        'senderId': merchantId,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await firestoreService.setDocument(FirebasePaths.supportTicket(ticketId), {
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }
}
