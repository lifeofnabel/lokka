import 'package:flutter/foundation.dart';

import '../models/merchantInviteModel.dart';
import '../services/inviteService.dart';

class InviteProvider extends ChangeNotifier {
  InviteProvider({required this.service});

  final InviteService service;

  bool isLoading = true;
  String? error;
  MerchantInviteModel? customerInvite;
  MerchantInviteModel? merchantInvite;

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final invites = await Future.wait([
        service.getOrCreateInvite('customer'),
        service.getOrCreateInvite('merchant'),
      ]);
      customerInvite = invites[0];
      merchantInvite = invites[1];
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
