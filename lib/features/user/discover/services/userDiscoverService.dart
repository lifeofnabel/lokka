import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/geoapifyService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';

class DiscoverFeedItem {
  const DiscoverFeedItem({
    required this.post,
    required this.merchant,
    required this.averageRating,
    required this.isLiked,
  });

  final FeedPostModel post;
  final PublicMerchantUserModel merchant;
  final double? averageRating;
  final bool isLiked;

  int get hotScore => post.likesCount + post.opensCount + post.clicksCount;
}

enum LocationSource { gps, manual, defaultArea, ipArea }

class UserLocation {
  const UserLocation({
    required this.lat,
    required this.lng,
    required this.source,
    this.label = '',
    this.city = '',
  });

  final double lat;
  final double lng;
  final LocationSource source;
  final String label;

  /// Stadt für den „wir raten"-Hinweis (Default: Frankfurt, IP: erkannte Stadt).
  final String city;

  /// Echter Standort geteilt (GPS) oder selbst getippt → „aktiv".
  /// Bei Default (Westendplatz) oder IP-Schätzung ist es false → Logo
  /// durchgestrichen (der Nutzer hat den Standort nicht aktiv freigegeben).
  bool get isShared =>
      source == LocationSource.gps || source == LocationSource.manual;

  /// Kein aktiv geteilter Standort → wir raten (Default oder grob per IP).
  bool get usedFallback => !isShared;
}

class UserDiscoverService {
  const UserDiscoverService({
    required this.firestoreService,
    required this.authService,
    required this.cacheService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;
  final LocalCacheService cacheService;

  String get _feedCacheKey =>
      'user.discover.feed.${authService.currentUser?.uid ?? 'guest'}';

  String get _interestsCacheKey =>
      'user.discover.interests.${authService.currentUser?.uid ?? 'guest'}';

  String get _walletIdsCacheKey =>
      'user.discover.walletIds.${authService.currentUser?.uid ?? 'guest'}';

  /// Kurze TTL statt der Standard-24h: Interessen/Wallet-Mitgliedschaft
  /// können sich innerhalb einer Session ändern (neuer Follow, Interessen
  /// bearbeitet), sollen aber einen Feed-Kaltstart nicht jedes Mal mit 2
  /// weiteren Netzwerk-Reads verzögern.
  static const _shortTtl = Duration(minutes: 10);

  /// Default-Standort, wenn weder GPS noch eine getippte Adresse vorliegt.
  /// Westendplatz 31, Frankfurt (Koordinaten fix hinterlegt – „nicht krank genau").
  static const westendplatz = UserLocation(
    lat: 50.1169,
    lng: 8.6584,
    source: LocationSource.defaultArea,
    label: 'Westendplatz 31, Frankfurt',
    city: 'Frankfurt',
  );

  String get _manualLocKey =>
      'user.location.manual.${authService.currentUser?.uid ?? 'guest'}';

  /// IP-Schätzung wird pro Gerät zwischengespeichert (IP ändert sich selten) –
  /// so kostet nicht jeder Feed-Load einen HTTP-Roundtrip.
  static const _ipLocKey = 'user.location.ip';

  /// Auflösung OHNE Permission-Prompt: getippte Adresse > bereits erlaubtes GPS
  /// > grobe IP-Verortung > Default Westendplatz. (Der Prompt kommt nur
  /// user-initiiert über das Popup.)
  Future<UserLocation> resolveLocation() async {
    final manual = await loadManualLocation();
    if (manual != null) return manual;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      if (serviceOn &&
          (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse)) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        return UserLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          source: LocationSource.gps,
          label: 'Dein Standort',
        );
      }
    } catch (_) {}
    // Kein GPS/keine Adresse: grob per IP verorten (v. a. Web), sonst Default.
    final ip = await _resolveIpLocation();
    return ip ?? westendplatz;
  }

  /// Grobe IP-Verortung (aus Cache oder per Geoapify), null bei Misserfolg.
  Future<UserLocation?> _resolveIpLocation() async {
    final cached = await cacheService.readMap(_ipLocKey);
    final clat = (cached?['lat'] as num?)?.toDouble();
    final clng = (cached?['lng'] as num?)?.toDouble();
    if (clat != null && clng != null) {
      final city = (cached?['city'] ?? '').toString();
      return UserLocation(
        lat: clat,
        lng: clng,
        source: LocationSource.ipArea,
        label: city.isEmpty ? 'In deiner Nähe' : city,
        city: city,
      );
    }
    try {
      final ip = await GeoapifyService().ipLocate();
      if (ip == null || !ip.hasCoordinates) return null;
      final city = ip.city.trim();
      await cacheService.writeMap(_ipLocKey, {
        'lat': ip.lat,
        'lng': ip.lng,
        'city': city,
      });
      return UserLocation(
        lat: ip.lat,
        lng: ip.lng,
        source: LocationSource.ipArea,
        label: city.isEmpty ? 'In deiner Nähe' : city,
        city: city,
      );
    } catch (_) {
      return null;
    }
  }

  /// User-initiiert (Button im Popup) – darf um Standortfreigabe bitten.
  Future<UserLocation?> requestGpsLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      await clearManualLocation();
      return UserLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        source: LocationSource.gps,
        label: 'Dein Standort',
      );
    } catch (_) {
      return null;
    }
  }

  /// GPS holen (user-initiiert, darf fragen) + per Geoapify reverse-geocoden,
  /// OHNE den Standort zu setzen – nur die Adresse zurückgeben, damit das
  /// Eingabefeld im Popup befüllt wird (User bestätigt dann selbst).
  Future<GeoResult?> gpsAddress() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return GeoapifyService().reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Manuell getippte Adresse persistieren / laden / löschen.
  Future<void> saveManualLocation(UserLocation loc) {
    return cacheService.writeMap(_manualLocKey, {
      'lat': loc.lat,
      'lng': loc.lng,
      'label': loc.label,
    });
  }

  Future<UserLocation?> loadManualLocation() async {
    final m = await cacheService.readMap(_manualLocKey);
    final lat = (m?['lat'] as num?)?.toDouble();
    final lng = (m?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return UserLocation(
      lat: lat,
      lng: lng,
      source: LocationSource.manual,
      label: (m?['label'] ?? '').toString(),
    );
  }

  Future<void> clearManualLocation() => cacheService.remove(_manualLocKey);

  Future<({List<String> categories})> loadInterests() async {
    final cached = await cacheService.readMap(_interestsCacheKey, ttl: _shortTtl);
    if (cached != null) {
      final categories = (cached['categories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      return (categories: categories);
    }
    return refreshInterests();
  }

  Future<({List<String> categories})> refreshInterests() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return (categories: <String>[]);
    final data = await firestoreService.readDocument(FirebasePaths.user(uid));
    final categories = (data?['interestCategories'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    await cacheService.writeMap(_interestsCacheKey, {'categories': categories});
    return (categories: categories);
  }

  /// The user's saved addresses (interest places) with a valid lat/lng — used as
  /// quick picks in the "Wo bist du?" location sheet.
  Future<List<Map<String, dynamic>>> loadFavoritePlaces() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return const [];
    final data = await firestoreService.readDocument(FirebasePaths.user(uid));
    final raw = (data?['interestPlaces'] as List?) ?? const [];
    final places = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((p) => p['lat'] is num && p['lng'] is num)
        .toList();
    // Default place first.
    places.sort((a, b) =>
        (b['isDefault'] == true ? 1 : 0) - (a['isDefault'] == true ? 1 : 0));
    return places;
  }

  /// Alle möglichen Herkünfte/Küchen (chooser/origins) – für den Origin-Filter
  /// im Filter-Sheet. Der Provider ruft das nur einmal lazy ab und cacht es.
  Future<List<String>> loadOrigins() => firestoreService.loadChooserOrigins();

  Future<List<PublicMerchantUserModel>> loadPublicMerchants() async {
    final cached = await loadCachedPublicMerchants();
    if (cached != null && cached.isNotEmpty) return cached;
    return refreshPublicMerchants();
  }

  Future<List<PublicMerchantUserModel>?> loadCachedPublicMerchants() async {
    final cached = await cacheService.readMapList('publicMerchants.active');
    if (cached == null) return null;
    return cached.map(PublicMerchantUserModel.fromMap).toList()
      ..sort((a, b) => a.shopName.toLowerCase().compareTo(b.shopName.toLowerCase()));
  }

  Future<List<PublicMerchantUserModel>> refreshPublicMerchants() async {
    // Plain collection read — no composite index needed.
    // isActive / isPublic are filtered client-side.
    final snap = await firestoreService
        .collection(FirebasePaths.publicMerchants)
        .get();

    final merchants = snap.docs
        .where((doc) {
          final d = doc.data();
          return (d['isActive'] as bool? ?? false) &&
              (d['isPublic'] as bool? ?? false);
        })
        .map((doc) => PublicMerchantUserModel.fromMap(
            {...doc.data(), 'merchantId': doc.id}))
        .where((m) => m.merchantId.isNotEmpty && m.shopName.isNotEmpty)
        .toList()
      ..sort((a, b) => a.shopName.toLowerCase().compareTo(b.shopName.toLowerCase()));
    await cacheService.writeMapList(
      'publicMerchants.active',
      merchants.map((merchant) => merchant.toMap()).toList(),
    );
    return merchants;
  }

  Future<List<DiscoverFeedItem>> loadFeedItems(
    List<PublicMerchantUserModel> merchants,
  ) async {
    final cached = await loadCachedFeedItems();
    if (cached != null && cached.isNotEmpty) return cached;
    return refreshFeedItems(merchants);
  }

  Future<List<DiscoverFeedItem>?> loadCachedFeedItems() async {
    final cached = await cacheService.readMapList(_feedCacheKey);
    if (cached == null) return null;
    final items = cached.map((item) {
      return DiscoverFeedItem(
        post: FeedPostModel.fromMap(
          Map<String, dynamic>.from(item['post'] as Map? ?? {}),
        ),
        merchant: PublicMerchantUserModel.fromMap(
          Map<String, dynamic>.from(item['merchant'] as Map? ?? {}),
        ),
        averageRating: (item['averageRating'] as num?)?.toDouble(),
        isLiked: item['isLiked'] as bool? ?? false,
      );
    }).toList();
    final subscribedMerchantIds = items.any((item) => item.post.isForRegulars)
        ? await _walletMerchantIds()
        : <String>{};
    return items
        .where((item) => _visibleForAudience(item.post, subscribedMerchantIds))
        .toList();
  }

  Future<List<DiscoverFeedItem>> refreshFeedItems(
    List<PublicMerchantUserModel> merchants,
  ) async {
    final merchantById = {
      for (final merchant in merchants) merchant.merchantId: merchant,
    };
    if (merchantById.isEmpty) return [];

    // Ganze Feed-Collection lesen, Sichtbarkeit clientseitig bestimmen
    // (kein Composite-Index nötig). So werden auch fällige geplante Posts
    // sichtbar – nicht nur server-seitig als aktiv markierte.
    final snap = await firestoreService.collection(FirebasePaths.feed).get();

    // Geliketе Posts in EINEM Read (statt einer Existenzprüfung pro Post).
    final likedIds = await _likedPostIds();
    Set<String>? subscribedMerchantIds;

    // 1) Kandidaten synchron filtern (kein Netzwerk im Loop außer Audience).
    final candidates =
        <({FeedPostModel post, PublicMerchantUserModel merchant})>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['isArchived'] == true || d['isPrivate'] == true) continue;
      final post = FeedPostModel.fromMap({...d, 'postId': doc.id});
      if (!_isLive(post)) continue; // Fix B: aktiv ODER fälliger Plan-Post
      if (post.imageUrl.trim().isEmpty) continue;
      if (post.isForRegulars) {
        subscribedMerchantIds ??= await _walletMerchantIds();
        if (!_visibleForAudience(post, subscribedMerchantIds)) continue;
      }
      // Fix A: fehlt der öffentliche Merchant-Eintrag (z. B. Profil noch nicht
      // „public"), aus den im Post gespeicherten Merchant-Feldern einen Ersatz
      // bauen, statt den Beitrag still zu verwerfen.
      final merchant = merchantById[post.merchantId] ?? _merchantFromPost(post);
      candidates.add((post: post, merchant: merchant));
    }

    // 2) Items OHNE Bewertungen zusammensetzen. Ein Read pro Beitrag (N+1)
    // würde bei einem Cache-Miss potenziell 50-100+ gleichzeitige Firestore-
    // Reads auslösen und damit den ersten sichtbaren Feed-Load blockieren —
    // Bewertungen werden stattdessen fensterweise nachgeladen, siehe
    // [fetchRatingsFor] (vom Provider für die jeweils sichtbaren Posts genutzt).
    final items = [
      for (final c in candidates)
        DiscoverFeedItem(
          post: c.post,
          merchant: c.merchant,
          averageRating: null,
          isLiked: likedIds.contains(c.post.postId),
        ),
    ];

    final sorted = _sortHottest(items);
    await cacheService.writeMapList(
      _feedCacheKey,
      sorted
          .map(
            (item) => {
              'post': item.post.toMap(),
              'merchant': item.merchant.toMap(),
              'averageRating': item.averageRating,
              'isLiked': item.isLiked,
            },
          )
          .toList(),
    );
    return sorted;
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Bitte einloggen');
    }

    final likePath = FirebasePaths.feedLike(postId, uid);
    final userLikePath = FirebasePaths.userLikedPost(uid, postId);
    final postPath = FirebasePaths.feedPost(postId);

    await firestoreService.runTransaction((tx) async {
      final postRef = firestoreService.document(postPath);
      final likeRef = firestoreService.document(likePath);
      final userRef = firestoreService.document(userLikePath);

      if (currentlyLiked) {
        tx.delete(likeRef);
        tx.delete(userRef);
        tx.update(postRef, {'likesCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'uid': uid, 'likedAt': FieldValue.serverTimestamp()});
        tx.set(userRef, {'postId': postId, 'likedAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likesCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> incrementOpen(String postId) {
    return firestoreService.setDocument(FirebasePaths.feedPost(postId), {
      'opensCount': FieldValue.increment(1),
      'clicksCount': FieldValue.increment(1),
    });
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
    String? merchantId,
  }) async {
    final uid = authService.currentUser?.uid;
    final ref = firestoreService.collection(FirebasePaths.contentReports).doc();
    await firestoreService.setDocument(FirebasePaths.contentReport(ref.id), {
      'reportId': ref.id,
      'postId': postId,
      'merchantId': merchantId ?? '',
      'userId': uid ?? '',
      'reason': reason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bewertungen für eine GEZIELTE, kleine Menge Beiträge (das aktuell
  /// sichtbare Fenster) — nicht für den ganzen Feed auf einmal, damit kein
  /// Burst gleichzeitiger Reads entsteht. Wird vom Provider nach jedem
  /// Sichtbar-Werden neuer Posts aufgerufen.
  Future<Map<String, double>> fetchRatingsFor(List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final ratings = await Future.wait(postIds.map(_averageRating));
    final result = <String, double>{};
    for (var i = 0; i < postIds.length; i++) {
      final rating = ratings[i];
      if (rating != null) result[postIds[i]] = rating;
    }
    return result;
  }

  Future<double?> _averageRating(String postId) async {
    final snap = await firestoreService
        .collection(FirebasePaths.feedReviews(postId))
        .get();
    final ratings = snap.docs
        .map((doc) => (doc.data()['rating'] as num?)?.toDouble())
        .whereType<double>()
        .where((rating) => rating >= 1 && rating <= 5)
        .toList();
    if (ratings.isEmpty) return null;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  /// Alle vom Nutzer gelikten Post-IDs in EINEM Read.
  Future<Set<String>> _likedPostIds() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return <String>{};
    final snap = await firestoreService
        .collection(FirebasePaths.userLikedPosts(uid))
        .get();
    return snap.docs
        .map((doc) => (doc.data()['postId'] as String?) ?? doc.id)
        .toSet();
  }

  /// Partner-IDs, denen der Nutzer folgt (= Merchants in seiner Wallet).
  /// Cache-first (kurze TTL) – der Feed-Kaltstart braucht dafür kein
  /// zusätzliches Netzwerk-Read; [refreshWalletMerchantIds] holt die
  /// tatsächlich frischen Daten (genutzt vom Hintergrund-Refresh).
  Future<Set<String>> loadWalletMerchantIds() async {
    final cached = await cacheService.readMap(_walletIdsCacheKey, ttl: _shortTtl);
    if (cached != null) {
      return (cached['ids'] as List?)?.map((e) => e.toString()).toSet() ??
          <String>{};
    }
    return refreshWalletMerchantIds();
  }

  Future<Set<String>> refreshWalletMerchantIds() async {
    final ids = await _walletMerchantIds();
    await cacheService.writeMap(_walletIdsCacheKey, {'ids': ids.toList()});
    return ids;
  }

  Future<Set<String>> _walletMerchantIds() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return <String>{};
    final snapshot =
        await firestoreService.collection(FirebasePaths.userWalletCards(uid)).get();
    return snapshot.docs
        .map((doc) => (doc.data()['merchantId'] as String?) ?? doc.id)
        .where((merchantId) => merchantId.trim().isNotEmpty)
        .toSet();
  }

  bool _visibleForAudience(
    FeedPostModel post,
    Set<String> subscribedMerchantIds,
  ) {
    if (!post.isForRegulars) return true;
    return subscribedMerchantIds.contains(post.merchantId);
  }

  /// Live, wenn aktiv ODER ein geplanter Post, dessen Zeitpunkt erreicht ist.
  bool _isLive(FeedPostModel post) {
    if (post.isActive) return true;
    final scheduled = post.scheduledAt;
    return post.isScheduled &&
        scheduled != null &&
        !scheduled.isAfter(DateTime.now());
  }

  /// Ersatz-Merchant aus den denormalisierten Feldern eines Posts.
  PublicMerchantUserModel _merchantFromPost(FeedPostModel post) {
    return PublicMerchantUserModel(
      merchantId: post.merchantId,
      shopName: post.merchantName.trim().isEmpty ? 'Partner' : post.merchantName,
      description: '',
      shopType: post.merchantShopType,
      address: '',
      fullAddress: '',
      logoUrl: post.merchantLogoUrl,
      coverUrl: '',
      phone: '',
      isActive: true,
      isPublic: true,
    );
  }

  List<DiscoverFeedItem> _sortHottest(List<DiscoverFeedItem> items) {
    items.sort((a, b) => b.hotScore.compareTo(a.hotScore));
    final top = items.take(6).toList()..shuffle(Random(DateTime.now().minute));
    return [...top, ...items.skip(6)];
  }
}
