import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/features/public/shop/services/publicShopService.dart';

/// Reine Logik der vier Menü-/Bestell-Modi + des Bestellcodes – ohne Firebase.
void main() {
  group('PublicCatalogConfig – Modus-Gating', () {
    test('Runner-Modus: bestellbar, „Senden", kein QR', () {
      const config = PublicCatalogConfig(catalogEnabled: true, modeRunner: true);
      expect(config.canOrder, isTrue);
      expect(config.showSend, isTrue);
      expect(config.showQrCashier, isFalse);
    });

    test('Tisch-Modus: bestellbar, „Senden", kein QR', () {
      const config = PublicCatalogConfig(catalogEnabled: true, modeTable: true);
      expect(config.canOrder, isTrue);
      expect(config.showSend, isTrue);
      expect(config.showQrCashier, isFalse);
    });

    test('Kassen-/QR-Modus: bestellbar, kein „Senden", QR', () {
      const config = PublicCatalogConfig(catalogEnabled: true, modeCashier: true);
      expect(config.canOrder, isTrue);
      expect(config.showSend, isFalse);
      expect(config.showQrCashier, isTrue);
    });

    test('Nur-Karte: NICHT bestellbar, kein Senden, kein QR', () {
      const config = PublicCatalogConfig(catalogEnabled: true, modeMenuOnly: true);
      expect(config.canOrder, isFalse);
      expect(config.showSend, isFalse);
      expect(config.showQrCashier, isFalse);
    });

    test('Katalog deaktiviert: nie bestellbar', () {
      const config = PublicCatalogConfig(catalogEnabled: false, modeTable: true);
      expect(config.canOrder, isFalse);
    });
  });

  group('Bestellcode (Idempotenz)', () {
    test('ist deterministisch und stabil pro ID', () {
      const id = 'aB3dEf9hKl';
      expect(PublicShopService.orderCodeFor(id),
          equals(PublicShopService.orderCodeFor(id)));
    });

    test('hat das LK-Präfix und ist großgeschrieben', () {
      final code = PublicShopService.orderCodeFor('abc123xyz');
      expect(code.startsWith('LK-'), isTrue);
      expect(code, equals(code.toUpperCase()));
    });

    test('verschiedene IDs → verschiedene Codes (Präfix berücksichtigt)', () {
      expect(PublicShopService.orderCodeFor('aaaaaa11'),
          isNot(equals(PublicShopService.orderCodeFor('bbbbbb22'))));
    });
  });
}
