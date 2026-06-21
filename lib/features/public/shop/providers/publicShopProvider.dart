import 'package:flutter/foundation.dart';

import '../../../../core/models/menuDesign.dart';
import '../../../merchant/catalog/models/itemCategoryData.dart';
import '../../../merchant/catalog/models/itemOptionGroup.dart';
import '../../../merchant/catalog/models/itemTagData.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import '../../../../core/cache/localCacheStorage.dart';
import '../../../merchant/catalog/models/runnerData.dart';
import '../../../merchant/tables/models/merchantTableData.dart';
import '../services/publicShopService.dart';

class PublicCartItem {
  const PublicCartItem({
    required this.item,
    required this.quantity,
    this.selectedOptions = const [],
    this.note = '',
  });

  final MerchantItemData item;
  final int quantity;

  /// Vom Kunden gewählte Optionen (mit Aufpreis).
  final List<ItemOption> selectedOptions;

  /// Pro-Artikel-Notiz/Extra (z.B. „ohne Zwiebeln").
  final String note;

  num get optionsSurcharge =>
      selectedOptions.fold<num>(0, (sum, option) => sum + option.price);

  num get unitPrice => item.price + optionsSurcharge;

  num get total => unitPrice * quantity;

  /// Eindeutige Zeilen-Signatur: gleicher Artikel mit anderen Optionen/Notiz
  /// landet als EIGENE Warenkorb-Zeile.
  String get signature {
    final ids = selectedOptions.map((option) => option.id).toList()..sort();
    return '${item.id}|${ids.join(',')}|$note';
  }

  PublicCartItem copyWith({int? quantity}) {
    return PublicCartItem(
      item: item,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions,
      note: note,
    );
  }
}

class PublicShopProvider extends ChangeNotifier {
  PublicShopProvider({required this.service});

  final PublicShopService service;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  String selectedCategoryId = 'all';
  Map<String, dynamic>? merchant;
  TableData? table;
  PublicCatalogConfig catalogConfig = PublicCatalogConfig.disabled;
  List<ItemCategoryData> categories = [];
  List<MerchantItemData> items = [];
  List<ItemTagData> itemTags = [];
  List<PublicCartItem> cart = [];
  String? createdOrderId;
  String? createdOrderCode;
  String? createdOrderMerchantId;

  /// Vom Merchant gewählte Gestaltung der Kundenkarte (Vorlage, Farbe,
  /// Hell/Dunkel, Spalten) – aus dem publicMerchants-Dokument.
  MenuDesign design = const MenuDesign();

  /// Wunsch/Notiz des Kunden für die gesamte Bestellung.
  String orderNote = '';

  /// Angelegte Tische (für die Tisch-/Platzwahl im Warenkorb).
  List<TableData> tables = [];

  /// Vom Kunden gewählter Tisch (überschreibt den QR-Tisch). Start = QR-Tisch.
  TableData? selectedTable;

  /// 'vor_ort' | 'mitnehmen'.
  String serviceType = 'vor_ort';

  /// Gewünschte Abholzeit bei „Mitnehmen" (frei, z.B. „12:30").
  String pickupTime = '';

  /// Zuletzt gewählte Abschluss-Art ('qr_cashier' | 'sent') – für die
  /// Bestätigungsseite (QR anzeigen ja/nein).
  String lastFulfillment = '';

  /// Runner (Name + Verfügbarkeit) aus dem publicMerchants-Doc – nur im
  /// Runner-Modus.
  List<RunnerData> runners = [];

  /// Aktuell gewählter Runner (Runner-Modus). Null = „Zuschauer" (nur ansehen).
  RunnerData? activeRunner;

  /// Wurde im Runner-Modus bereits gewählt, wer reingeht? Steuert die
  /// automatische „Wer geht rein?"-Abfrage beim Betreten der Karte.
  bool runnerChosen = false;

  /// Freitext-Suche in der Karte (v.a. Runner-Modus, schnelles Finden).
  String itemSearch = '';

  /// Merchant-ID dieser Sitzung – für die geräte-lokale Runner-Vorauswahl.
  String _merchantId = '';
  static const _lastRunnerKeyPrefix = 'lokka_last_runner_';

  bool get catalogAvailable => catalogConfig.catalogEnabled;

  /// Bestellen möglich = Katalog aktiv und ein Bestell-Modus (Tisch/Vor-Kasse/
  /// Runner). „Nur Speisekarte" ⇒ kein Warenkorb. Im Runner-Modus muss zudem
  /// ein Runner (kein Zuschauer) gewählt sein. Tischwahl passiert im Warenkorb.
  bool get canOrder {
    if (!catalogConfig.canOrder) return false;
    if (catalogConfig.modeRunner) return activeRunner != null;
    return true;
  }

  /// Verfügbare Runner zur direkten Auswahl („Wer geht rein?").
  List<RunnerData> get availableRunners =>
      runners.where((runner) => runner.available).toList();

  /// Runner-Modus: direkt wählen, wer gerade bedient. `null` = „Zuschauer"
  /// (nur ansehen, kein Bestellen). Kein PIN/Login mehr.
  void selectRunner(RunnerData? runner) {
    activeRunner = runner;
    runnerChosen = true;
    notifyListeners();
    // Geräte-lokal merken, wer zuletzt gewählt war (nur dieses Gerät).
    if (_merchantId.isNotEmpty) {
      LocalCacheStorage.write(
          '$_lastRunnerKeyPrefix$_merchantId', runner?.id ?? '');
    }
  }

  /// Setzt beim Laden den zuletzt an DIESEM Gerät gewählten Runner vor (nur
  /// Runner-Modus, nur wenn er noch verfügbar ist) – spart die Abfrage. Rein
  /// lokal, nicht über Geräte hinweg.
  Future<void> _restoreLastRunner() async {
    if (!catalogConfig.modeRunner || runnerChosen || _merchantId.isEmpty) return;
    final saved =
        await LocalCacheStorage.read('$_lastRunnerKeyPrefix$_merchantId');
    if (saved == null || saved.isEmpty) return;
    for (final runner in runners) {
      if (runner.id == saved && runner.available) {
        activeRunner = runner;
        runnerChosen = true;
        notifyListeners();
        return;
      }
    }
  }

  void setItemSearch(String value) {
    itemSearch = value;
    notifyListeners();
  }

  /// Tisch, der der Bestellung zugeordnet wird (Kundenwahl vor QR-Tisch).
  TableData? get effectiveTable => selectedTable ?? table;

  List<MerchantItemData> get visibleItems {
    final query = itemSearch.trim().toLowerCase();
    if (query.isNotEmpty) {
      // Suche schlägt die Kategorie-Auswahl: über alle Artikel hinweg finden.
      return items
          .where((item) =>
              item.name.toLowerCase().contains(query) ||
              item.articleNumber.toLowerCase().contains(query))
          .toList();
    }
    if (selectedCategoryId == 'all') return items;
    return items.where((item) => item.categoryId == selectedCategoryId).toList();
  }

  num get totalPrice => cart.fold<num>(0, (sum, item) => sum + item.total);

  Future<void> load({
    required String merchantId,
    String tableId = '',
  }) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      final basics = await Future.wait<Object?>([
        service.loadMerchant(merchantId),
        service.loadTable(merchantId, tableId),
        service.loadCatalogConfig(merchantId),
      ]);
      merchant = basics[0] as Map<String, dynamic>?;
      table = basics[1] as TableData?;
      catalogConfig = basics[2] as PublicCatalogConfig;
      selectedTable = table; // QR-Tisch vorgewählt, im Warenkorb änderbar.
      design = MenuDesign.fromMap(merchant);
      runners = RunnerData.listFromRaw(merchant?['runners']);
      _merchantId = merchantId;
      await _restoreLastRunner();
      if (!catalogAvailable) {
        categories = [];
        items = [];
        itemTags = [];
        tables = [];
        cart = [];
        return;
      }

      final catalog = await Future.wait<Object?>([
        service.loadCategories(merchantId),
        service.loadItemTags(merchantId),
        service.loadItems(merchantId),
        service.loadTables(merchantId),
      ]);
      categories = catalog[0] as List<ItemCategoryData>;
      itemTags = catalog[1] as List<ItemTagData>;
      items = catalog[2] as List<MerchantItemData>;
      tables = catalog[3] as List<TableData>;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String id) {
    selectedCategoryId = id;
    notifyListeners();
  }

  void setOrderNote(String value) {
    orderNote = value;
  }

  void setServiceType(String value) {
    serviceType = value;
    notifyListeners();
  }

  void setPickupTime(String value) {
    pickupTime = value;
    notifyListeners();
  }

  void setSelectedTable(TableData? value) {
    selectedTable = value;
    notifyListeners();
  }

  /// Einfaches Hinzufügen (Artikel ohne Optionen, z.B. Empfehlungen).
  void addItem(MerchantItemData item) => addConfiguredItem(item: item);

  /// Fügt einen Artikel mit gewählten Optionen + Pro-Artikel-Notiz hinzu.
  /// Gleiche Kombination = Menge erhöhen, sonst neue Zeile.
  void addConfiguredItem({
    required MerchantItemData item,
    List<ItemOption> options = const [],
    String note = '',
  }) {
    // Nach einer abgeschlossenen Bestellung startet das Hinzufügen eine neue
    // Bestell-Session (z. B. über die „Lust auf mehr?"-Empfehlungen).
    if (createdOrderId != null) {
      createdOrderId = null;
      createdOrderCode = null;
      createdOrderMerchantId = null;
      lastFulfillment = '';
      orderNote = '';
    }
    final entry = PublicCartItem(
      item: item,
      quantity: 1,
      selectedOptions: options,
      note: note.trim(),
    );
    final next = [...cart];
    final index = next.indexWhere((line) => line.signature == entry.signature);
    if (index == -1) {
      next.add(entry);
    } else {
      next[index] = next[index].copyWith(quantity: next[index].quantity + 1);
    }
    cart = next;
    notifyListeners();
  }

  void incrementLine(PublicCartItem entry) {
    final next = [...cart];
    final index = next.indexWhere((line) => line.signature == entry.signature);
    if (index == -1) return;
    next[index] = next[index].copyWith(quantity: next[index].quantity + 1);
    cart = next;
    notifyListeners();
  }

  void decrementLine(PublicCartItem entry) {
    final next = [...cart];
    final index = next.indexWhere((line) => line.signature == entry.signature);
    if (index == -1) return;
    final current = next[index];
    if (current.quantity <= 1) {
      next.removeAt(index);
    } else {
      next[index] = current.copyWith(quantity: current.quantity - 1);
    }
    cart = next;
    notifyListeners();
  }

  /// Live-Status der gerade abgesendeten Bestellung für die Bestätigungsseite.
  /// Erzeugt EINEN Stream – in initState der Seite aufrufen, nicht in build,
  /// sonst wird bei jedem Rebuild neu abonniert.
  Stream<String> watchCreatedOrderStatus() {
    final id = createdOrderId;
    final mId = createdOrderMerchantId;
    if (id == null || mId == null) return Stream<String>.value('new');
    return service.watchOrderStatus(mId, id);
  }

  Future<bool> placeOrder(String merchantId, {required String fulfillment}) async {
    if (cart.isEmpty || !canOrder) return false;
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final result = await service.createOrder(
        merchantId: merchantId,
        table: effectiveTable,
        totalPrice: totalPrice,
        note: orderNote.trim(),
        customerName: activeRunner?.name ?? 'Gast',
        runnerId: activeRunner?.id ?? '',
        // Runner-Modus kennt kein „Mitnehmen"/Abholzeit → immer Vor Ort.
        serviceType: catalogConfig.modeRunner ? 'vor_ort' : serviceType,
        pickupTime: (!catalogConfig.modeRunner && serviceType == 'mitnehmen')
            ? pickupTime.trim()
            : '',
        fulfillment: fulfillment,
        items: cart
            .map((entry) => {
                  'itemId': entry.item.id,
                  'title': entry.item.name,
                  'name': entry.item.name,
                  'quantity': entry.quantity,
                  'unitPrice': entry.unitPrice,
                  'totalPrice': entry.total,
                  'articleNumber': entry.item.articleNumber,
                  'note': entry.note,
                  'options': entry.selectedOptions
                      .map((option) => {'name': option.name, 'price': option.price})
                      .toList(),
                })
            .toList(),
      );
      createdOrderId = result.id;
      createdOrderCode = result.code;
      createdOrderMerchantId = merchantId;
      lastFulfillment = fulfillment;
      cart = [];
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
