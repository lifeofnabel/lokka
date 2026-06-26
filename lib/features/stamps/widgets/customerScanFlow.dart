import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/firebasePaths.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../merchant/stamps/pages/merchantCustomerStampPage.dart';
import '../../user/wallet/utils/walletCode.dart';
import '../services/stampFunctionsService.dart';
import 'stampScanner.dart';

/// ONE scanner for the whole counter — it auto-detects what was scanned/typed,
/// no "what do you want to scan?" chooser:
///   • Customer wallet QR ("lokka://wallet/{uid}/{mid}/{code}") → stamp/points page
///   • Typed wallet code ("A123-B456") → resolved to a uid → stamp/points page
///   • Order QR/code ("LK-XXXXXX") → confirmed via [onOrderCode]
Future<void> startMerchantScan(
  BuildContext context, {
  required String merchantId,
  required FirestoreService firestore,
  required Future<bool> Function(String code) onOrderCode,
  StampFunctionsService? functions,
}) async {
  final texts = context.read<LanguageService>();
  final nav = Navigator.of(context, rootNavigator: true);
  final fn = functions ?? StampFunctionsService();

  void open(String customerUid) {
    nav.pop();
    nav.push(MaterialPageRoute<void>(
      builder: (_) => MerchantCustomerStampPage(
        customerUid: customerUid,
        merchantId: merchantId,
        functions: fn,
      ),
    ));
  }

  await showStampScanner(
    context,
    title: texts.text('merchant.stampScan.scanTitle'),
    hint: texts.text('merchant.stampScan.scanHint'),
    manualLabel: texts.text('merchant.stampScan.scanManual'),
    onConfirm: (raw) async {
      // 1. QR path — the URI already carries the uid.
      final parsed = _parseWalletQr(raw);
      if (parsed != null) {
        final (uid, mid) = parsed;
        if (mid != merchantId) {
          return StampScanOutcome.fail(texts.text('merchant.stampScan.wrongMerchant'));
        }
        open(uid);
        return const StampScanOutcome.ok();
      }
      // 2. Typed/printed code path — resolve the code → uid via THIS merchant's
      //    customer index (merchants/{mid}/customers where walletCode == code).
      final code = _normalizeWalletCode(raw);
      if (code != null) {
        String? uid;
        try {
          uid = await _resolveCustomerByCode(firestore, merchantId, code);
        } catch (_) {
          return StampScanOutcome.fail(texts.text('merchant.stampScan.err.generic'));
        }
        if (uid == null) {
          return StampScanOutcome.fail(texts.text('merchant.stampScan.codeNotFound'));
        }
        open(uid);
        return const StampScanOutcome.ok();
      }
      // 3. Order QR/code ("LK-XXXXXX") → confirm the pre-paid order.
      final order = _extractOrderCode(raw);
      if (order != null) {
        bool okOrder = false;
        try {
          okOrder = await onOrderCode(order);
        } catch (_) {
          okOrder = false;
        }
        return okOrder
            ? StampScanOutcome.ok(texts.text('merchant.scan.successBody'))
            : StampScanOutcome.fail(texts.text('merchant.scan.notFound'));
      }
      return StampScanOutcome.fail(texts.text('merchant.stampScan.invalidQr'));
    },
  );
}

/// Extracts an order code ("LK-XXXXXX") from a raw scan/typed value, tolerating
/// a wrapping URL (`?code=` or last path segment). Returns null if it doesn't
/// look like an order code, so wallet QRs/codes are never mistaken for orders.
String? _extractOrderCode(String raw) {
  var v = raw.trim();
  if (v.isEmpty) return null;
  final uri = Uri.tryParse(v);
  if (uri != null && (uri.hasScheme || v.contains('/'))) {
    if (uri.queryParameters['code'] != null) {
      v = uri.queryParameters['code']!;
    } else if (uri.pathSegments.isNotEmpty) {
      v = uri.pathSegments.last;
    }
  }
  v = v.trim();
  final normalized = v.toUpperCase().replaceAll(RegExp('[^0-9A-Z]'), '');
  return normalized.startsWith('LK') ? v : null;
}

/// Returns (customerUid, merchantId) from a wallet QR, or null. Tolerates both
/// the custom scheme and an https URL that carries the same path.
(String, String)? _parseWalletQr(String raw) {
  final value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  // lokka://wallet/{uid}/{mid}/{code}  → host 'wallet', segments [uid, mid, ...]
  List<String> segs = uri.pathSegments;
  if (uri.host == 'wallet') {
    if (segs.length >= 2) return (segs[0], segs[1]);
  }
  // https://.../wallet/{uid}/{mid}/{code}
  final i = segs.indexOf('wallet');
  if (i >= 0 && segs.length >= i + 3) return (segs[i + 1], segs[i + 2]);
  return null;
}

/// Normalises a typed/printed code (`a123-b456`, `A123 B456`, …) to the stored
/// 8-char form, or null if it isn't a valid wallet code.
String? _normalizeWalletCode(String raw) {
  final c = raw.toUpperCase().replaceAll(RegExp('[^0-9A-Z]'), '');
  return WalletCode.isValid(c) ? c : null;
}

/// Looks up which customer owns [code] for this merchant. The merchant can read
/// its own `customers` subcollection; the user stores `walletCode` there on
/// follow. Single-field equality → no composite index needed.
Future<String?> _resolveCustomerByCode(
  FirestoreService firestore,
  String merchantId,
  String code,
) async {
  final snap = await firestore
      .collection(FirebasePaths.merchantCustomers(merchantId))
      .where('walletCode', isEqualTo: code)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  final doc = snap.docs.first;
  final uid = (doc.data()['uid'] ?? doc.id).toString();
  return uid.isEmpty ? null : uid;
}
