import 'dart:async';
import 'dart:math';

import 'package:lokka/core/services/geoapifyService.dart';
import 'package:lokka/core/utils/locationUtils.dart';

import 'package:flutter/foundation.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart';

enum DiscoverSort { forYou, hottest, newest, mostLiked }

/// Oberer Feed-Umschalter: Für dich · Folge ich · Neben mir.
enum DiscoverFeedMode { forYou, following, nearMe }

class UserDiscoverProvider extends ChangeNotifier {
  UserDiscoverProvider({required UserDiscoverService service}) : _service = service {
    load();
  }

  final UserDiscoverService _service;

  List<PublicMerchantUserModel> _merchants = [];
  List<DiscoverFeedItem> _allItems = [];
  List<DiscoverFeedItem> _visibleItems = [];
  UserLocation _location = UserDiscoverService.westendplatz;
  bool _isLoading = true;
  final bool _isLoadingMore = false;
  String? _error;
  String? _shopType;
  String _city = 'Frankfurt';
  String _radius = 'Egal';
  bool _openNow = false;
  DiscoverSort _sort = DiscoverSort.forYou;
  DiscoverFeedMode _mode = DiscoverFeedMode.forYou;
  String _search = '';
  int _limit = 6;
  Set<String> _interestCategories = {};
  Set<String> _followingMerchantIds = {};
  List<DiscoverFeedItem> _orderedAll = [];
  // Stabiler Seed pro App-Session → die „Für dich"-Reihenfolge würfelt sich
  // NICHT bei jedem Rebuild/Refresh/Like neu (das war das sichtbare Ruckeln),
  // variiert aber von Session zu Session.
  final int _sessionSalt = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;

  List<PublicMerchantUserModel> get merchants => _merchants.take(15).toList();
  List<DiscoverFeedItem> get visibleItems => _visibleItems;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get usedFallbackLocation => _location.usedFallback;
  UserLocation get location => _location;

  /// true = echter Standort (GPS/getippt) → Logo normal; false = Default
  /// (Westendplatz) → Logo durchgestrichen.
  bool get hasSharedLocation => _location.isShared;
  String get locationLabel =>
      _location.label.isEmpty ? 'Standort wählen' : _location.label;
  String? get shopType => _shopType;
  String get city => _city;
  String get radius => _radius;
  bool get openNow => _openNow;
  DiscoverSort get sort => _sort;
  DiscoverFeedMode get mode => _mode;

  /// Folgt der Nutzer überhaupt jemandem (= Partner in der Wallet)?
  bool get hasFollowing => _followingMerchantIds.isNotEmpty;
  bool get canLoadMore => _visibleItems.length < _orderedAll.length;

  List<String> get shopTypes {
    final values = _merchants.map((m) => m.shopType).where((v) => v.isNotEmpty).toSet().toList();
    values.sort();
    return values;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _location = await _service.resolveLocation();
      final interests = await _service.loadInterests();
      _interestCategories = interests.categories.toSet();
      _merchants = await _service.loadPublicMerchants();
      _allItems = await _service.loadFeedItems(_merchants);
      _followingMerchantIds = await _service.loadWalletMerchantIds();
      _applyFilters(resetLimit: true);
      unawaited(_refreshFreshData());
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void applySearch(String value) {
    _search = value.trim().toLowerCase();
    _applyFilters(resetLimit: true);
  }

  /// „Für dich" ↔ „Folge ich" umschalten.
  void setMode(DiscoverFeedMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _applyFilters(resetLimit: true);
  }

  /// Frische Daten nachladen – z. B. nach Rückkehr von der Beitrag-Detailseite,
  /// damit eine gerade abgegebene Bewertung sofort sichtbar wird.
  Future<void> refreshFresh() => _refreshFreshData();

  /// Manuell getippte Adresse übernehmen (aus dem Location-Popup).
  /// The user's saved addresses (for quick picks in the location sheet).
  Future<List<Map<String, dynamic>>> loadFavoritePlaces() =>
      _service.loadFavoritePlaces();

  Future<void> setManualLocation({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final loc = UserLocation(
      lat: lat,
      lng: lng,
      source: LocationSource.manual,
      label: label,
    );
    await _service.saveManualLocation(loc);
    _location = loc;
    _applyFilters(resetLimit: true);
  }

  /// „Überspringen" → Default Westendplatz (Logo durchgestrichen).
  Future<void> useDefaultLocation() async {
    await _service.clearManualLocation();
    _location = UserDiscoverService.westendplatz;
    _applyFilters(resetLimit: true);
  }

  /// GPS → Adresse (reverse-geocoded), OHNE zu setzen – fürs Befüllen des
  /// Eingabefelds im „Wo bist du?"-Popup. Rückgabe null = nicht verfügbar.
  Future<GeoResult?> gpsSuggestAddress() => _service.gpsAddress();

  /// Geräte-Standort verwenden (user-initiiert, darf um Freigabe bitten).
  Future<bool> useGpsLocation() async {
    final loc = await _service.requestGpsLocation();
    if (loc == null) return false;
    _location = loc;
    _applyFilters(resetLimit: true);
    return true;
  }

  /// Distanz eines Beitrags (km) zum aktuellen Standort, null ohne Koordinaten.
  double? distanceKmForItem(DiscoverFeedItem item) {
    if (!item.merchant.hasCoordinates) return null;
    return LocationUtils.distanceKm(
        _location.lat, _location.lng, item.merchant.lat!, item.merchant.lng!);
  }

  void applyFilters({
    String? city,
    String? radius,
    String? shopType,
    bool? openNow,
    DiscoverSort? sort,
  }) {
    _city = city?.trim().isEmpty ?? true ? 'Frankfurt' : city!.trim();
    _radius = radius ?? _radius;
    _shopType = shopType?.isEmpty ?? true ? null : shopType;
    _openNow = openNow ?? _openNow;
    _sort = sort ?? _sort;
    _applyFilters(resetLimit: true);
  }

  void resetFilters() {
    _city = 'Frankfurt';
    _radius = 'Egal';
    _shopType = null;
    _openNow = false;
    _sort = DiscoverSort.forYou;
    _applyFilters(resetLimit: true);
  }

  void loadMore() {
    _limit += 7;
    _slice(); // nur mehr anzeigen, NICHT neu ordnen
  }

  Future<void> toggleLike(DiscoverFeedItem item) async {
    await _service.toggleLike(item.post.postId, item.isLiked);
    final updated = DiscoverFeedItem(
      post: item.post,
      merchant: item.merchant,
      averageRating: item.averageRating,
      isLiked: !item.isLiked,
    );
    // In-place aktualisieren – KEINE Neuordnung (kein Springen beim Liken).
    for (final list in [_allItems, _orderedAll]) {
      final i = list.indexWhere((it) => it.post.postId == item.post.postId);
      if (i >= 0) list[i] = updated;
    }
    _slice();
  }

  Future<void> incrementOpen(String postId) => _service.incrementOpen(postId);

  Future<void> reportPost({
    required String postId,
    required String reason,
    String? merchantId,
  }) =>
      _service.reportPost(
        postId: postId,
        reason: reason,
        merchantId: merchantId,
      );

  Future<void> _refreshFreshData() async {
    try {
      final merchants = await _service.refreshPublicMerchants();
      final items = await _service.refreshFeedItems(merchants);
      _merchants = merchants;
      _allItems = items;
      _followingMerchantIds = await _service.loadWalletMerchantIds();
      _applyFilters(resetLimit: false);
    } catch (_) {}
  }

  void _applyFilters({required bool resetLimit}) {
    // Reihenfolge EINMAL stabil berechnen (deterministisch dank Session-Seed).
    _orderedAll = _filteredSortedItems();
    if (resetLimit) _limit = 6;
    _slice();
  }

  /// Nur den sichtbaren Ausschnitt neu schneiden – ohne Neuordnung.
  void _slice() {
    _visibleItems = _orderedAll.take(_limit).toList();
    notifyListeners();
  }

  List<DiscoverFeedItem> _filteredSortedItems() {
    var items = [..._allItems];
    // „Folge ich": nur Beiträge von Partnern in der Wallet.
    if (_mode == DiscoverFeedMode.following) {
      items = items
          .where((item) =>
              _followingMerchantIds.contains(item.merchant.merchantId))
          .toList();
    }
    if (_search.isNotEmpty) {
      items = items.where((item) {
        final haystack = [
          item.post.title,
          item.post.subtitle,
          item.merchant.shopName,
          item.merchant.shopType,
        ].join(' ').toLowerCase();
        return haystack.contains(_search);
      }).toList();
    }
    if (_shopType != null) {
      items = items.where((item) => item.merchant.shopType == _shopType).toList();
    }
    if (_openNow) {
      items = items.where((item) => _isOpenNow(item.merchant.openingHours)).toList();
    }
    if (_radius != 'Egal') {
      final km = int.tryParse(_radius.split(' ').first);
      if (km != null) {
        items = items.where((item) {
          if (!item.merchant.hasCoordinates) return false;
          return LocationUtils.distanceKm(
                _location.lat,
                _location.lng,
                item.merchant.lat!,
                item.merchant.lng!,
              ) <=
              km;
        }).toList();
      }
    }
    // „Neben mir": nur Beiträge mit Merchant-Koordinaten, nächste zuerst.
    if (_mode == DiscoverFeedMode.nearMe) {
      items = items.where((it) => it.merchant.hasCoordinates).toList();
      items.sort((a, b) =>
          (distanceKmForItem(a) ?? 1e9).compareTo(distanceKmForItem(b) ?? 1e9));
      return items;
    }
    // „Folge ich": neueste Beiträge der abonnierten Partner zuerst.
    if (_mode == DiscoverFeedMode.following) {
      items.sort((a, b) => _postTime(b).compareTo(_postTime(a)));
      return items;
    }
    // „Für dich": Filtersheet-Sortierung – Standard = schlauer Algorithmus.
    switch (_sort) {
      case DiscoverSort.newest:
        items.sort((a, b) => _postTime(b).compareTo(_postTime(a)));
        return items;
      case DiscoverSort.hottest:
        items.sort((a, b) => b.hotScore.compareTo(a.hotScore));
        return items;
      case DiscoverSort.mostLiked:
        items.sort((a, b) => b.post.likesCount.compareTo(a.post.likesCount));
        return items;
      case DiscoverSort.forYou:
        return _forYouOrder(items);
    }
  }

  DateTime _postTime(DiscoverFeedItem it) =>
      it.post.publishedAt ?? it.post.createdAt ?? DateTime(1970);

  /// Deterministischer „Zufall" pro Post (+ Session-Seed): stabil innerhalb
  /// einer Session (kein Ruckeln), variiert aber von Session zu Session.
  double _stableJitter(String postId) {
    final h = (postId.hashCode ^ _sessionSalt) & 0x7fffffff;
    return (h % 1000) / 1000.0;
  }

  /// „Für dich"-Algorithmus – abwechslungsreich statt langweilig:
  /// • mehrere Frische-Tiers (6 h / 24 h / 3 T / 1 W / älter)
  /// • Likes dominieren innerhalb eines Tiers, kleiner Review- & Interessen-Boost
  /// • Zufalls-Jitter, damit der Feed nicht jedes Mal identisch ist
  /// • Merchant-Interleaving (kein Merchant zweimal direkt hintereinander)
  /// • die obersten 3 sind IMMER random aus den letzten 6 Stunden
  List<DiscoverFeedItem> _forYouOrder(List<DiscoverFeedItem> items) {
    if (items.isEmpty) return items;
    final now = DateTime.now();

    double ageHours(DiscoverFeedItem it) =>
        now.difference(_postTime(it)).inMinutes / 60.0;

    double score(DiscoverFeedItem it) {
      final h = ageHours(it);
      double s;
      if (h <= 6) {
        s = 1000;
      } else if (h <= 24) {
        s = 700;
      } else if (h <= 72) {
        s = 400;
      } else if (h <= 168) {
        s = 200;
      } else {
        s = 50;
      }
      s += it.post.likesCount * 12; // Likes dominieren innerhalb eines Tiers
      s += (it.post.opensCount + it.post.clicksCount) * 2;
      if (it.averageRating != null) {
        s += (it.averageRating! - 3) * 30; // -60..+60, kleiner Einfluss
      }
      if (_interestCategories.contains(it.merchant.shopType)) s += 250;
      s += _stableJitter(it.post.postId) * 120; // Abwechslung, aber stabil
      return s;
    }

    final scored = [...items]..sort((a, b) => score(b).compareTo(score(a)));
    final varied = _interleaveByMerchant(scored);

    // Top 3 random – bevorzugt aus den letzten 6 Stunden.
    final fresh = varied.where((it) => ageHours(it) <= 6).toList();
    final pool = fresh.length >= 3 ? fresh : varied;
    final top = (pool.take(min(8, pool.length)).toList()
          ..shuffle(Random(_sessionSalt)))
        .take(3)
        .toList();
    final topIds = top.map((it) => it.post.postId).toSet();
    final rest =
        varied.where((it) => !topIds.contains(it.post.postId)).toList();
    return [...top, ...rest];
  }

  /// Vermeidet zwei Beiträge desselben Merchants direkt hintereinander.
  List<DiscoverFeedItem> _interleaveByMerchant(List<DiscoverFeedItem> items) {
    final queue = [...items];
    final result = <DiscoverFeedItem>[];
    String? last;
    while (queue.isNotEmpty) {
      var idx = queue.indexWhere((it) => it.merchant.merchantId != last);
      if (idx < 0) idx = 0;
      final picked = queue.removeAt(idx);
      result.add(picked);
      last = picked.merchant.merchantId;
    }
    return result;
  }
}

bool _isOpenNow(Map<String, dynamic>? hours) {
  if (hours == null || hours.isEmpty) return false;
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final now = DateTime.now();
  final data = hours[days[now.weekday - 1]];
  if (data is! Map) return false;
  final open = data['open']?.toString();
  final close = data['close']?.toString();
  if (open == null || close == null) return false;
  final current = now.hour * 60 + now.minute;
  final openParts = open.split(':').map(int.tryParse).toList();
  final closeParts = close.split(':').map(int.tryParse).toList();
  if (openParts.length < 2 || closeParts.length < 2) return false;
  final openMinutes = (openParts[0] ?? 0) * 60 + (openParts[1] ?? 0);
  final closeMinutes = (closeParts[0] ?? 0) * 60 + (closeParts[1] ?? 0);
  return current >= openMinutes && current <= closeMinutes;
}

