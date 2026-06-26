import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/core/services/connectivityService.dart';
import 'package:lokka/features/merchant/catalog/models/merchantItemData.dart';
import 'package:lokka/features/merchant/tables/models/merchantTableData.dart';
import 'package:lokka/features/public/shop/providers/publicShopProvider.dart';
import 'package:lokka/features/public/shop/services/publicShopService.dart';

/// Edge-Cases der Bestell-Erstellung (#1 Doppel-Bestellung, #2 Offline,
/// #4 leerer Warenkorb) – mit leichten Fakes, ohne Firebase.
void main() {
  final item = MerchantItemData.fromMap({'id': 'i1', 'name': 'Cola', 'price': 2});

  PublicShopProvider build(_FakeShopService svc, {required bool online}) {
    final provider = PublicShopProvider(
      service: svc,
      connectivity: _FakeConnectivity(online),
    );
    provider.catalogConfig =
        const PublicCatalogConfig(catalogEnabled: true, modeTable: true);
    return provider;
  }

  test('#4 Leerer Warenkorb → kein Schreibvorgang', () async {
    final svc = _FakeShopService();
    final provider = build(svc, online: true);
    final ok = await provider.placeOrder('m1', fulfillment: 'sent');
    expect(ok, isFalse);
    expect(svc.createOrderIds, isEmpty);
  });

  test('#2 Offline → blockiert mit Hinweis, kein Schreibvorgang', () async {
    final svc = _FakeShopService();
    final provider = build(svc, online: false)..addItem(item);
    final ok = await provider.placeOrder('m1', fulfillment: 'sent');
    expect(ok, isFalse);
    expect(provider.saveErrorKey, 'public.shop.offlineError');
    expect(svc.createOrderIds, isEmpty);
  });

  test('Online Happy-Path → genau eine Bestellung', () async {
    final svc = _FakeShopService();
    final provider = build(svc, online: true)..addItem(item);
    final ok = await provider.placeOrder('m1', fulfillment: 'sent');
    expect(ok, isTrue);
    expect(svc.createOrderIds.length, 1);
    expect(provider.createdOrderCode, isNotNull);
    expect(provider.cart, isEmpty);
  });

  test('#1 Retry nach Fehler nutzt dieselbe ID (kein Duplikat)', () async {
    final svc = _FakeShopService()..throwOnCreate = true;
    final provider = build(svc, online: true)..addItem(item);

    final first = await provider.placeOrder('m1', fulfillment: 'sent');
    expect(first, isFalse);

    svc.throwOnCreate = false;
    final second = await provider.placeOrder('m1', fulfillment: 'sent');
    expect(second, isTrue);

    // Zwei Schreibversuche, aber identische ID und nur EINE erzeugte ID.
    expect(svc.createOrderIds.length, 2);
    expect(svc.createOrderIds.toSet().length, 1);
    expect(svc.newIdCalls, 1);
  });

  test('#1 Recovery: Write „scheitert", Bestellung existiert doch → Erfolg',
      () async {
    final svc = _FakeShopService()
      ..throwOnCreate = true
      ..recoveryCode = 'LK-RECOV';
    final provider = build(svc, online: true)..addItem(item);

    final ok = await provider.placeOrder('m1', fulfillment: 'sent');
    expect(ok, isTrue);
    expect(provider.createdOrderCode, 'LK-RECOV');
  });
}

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity(this.online);
  final bool online;
  @override
  Future<bool> isOnline() async => online;
}

class _FakeShopService implements PublicShopService {
  int newIdCalls = 0;
  final List<String> createOrderIds = [];
  bool throwOnCreate = false;
  String? recoveryCode;

  @override
  String newOrderId(String merchantId) {
    newIdCalls++;
    return 'order-123';
  }

  @override
  Future<({String id, String code})> createOrder({
    required String merchantId,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required num totalPrice,
    TableData? table,
    String note = '',
    String customerName = 'Gast',
    String runnerId = '',
    String serviceType = 'vor_ort',
    String pickupTime = '',
    String fulfillment = 'sent',
  }) async {
    createOrderIds.add(orderId);
    if (throwOnCreate) throw Exception('network');
    return (id: orderId, code: PublicShopService.orderCodeFor(orderId));
  }

  @override
  Future<String?> existingOrderCode(String merchantId, String orderId) async {
    return recoveryCode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
