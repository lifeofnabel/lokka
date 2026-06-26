import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/features/merchant/feedManager/services/merchantFeedCreateService.dart';
import 'package:lokka/features/merchant/tools/services/merchantToolsService.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';

void main() {
  group('MerchantFeedCreateService.ctaRouteFor', () {
    const mid = 'm1';

    test('profile target → partner page', () {
      expect(
        MerchantFeedCreateService.ctaRouteFor(merchantId: mid, linkType: 'profile', targetId: ''),
        '/user/partners/m1',
      );
    });

    test('stampCard target → wallet/stamps deep link', () {
      expect(
        MerchantFeedCreateService.ctaRouteFor(merchantId: mid, linkType: 'stampCard', targetId: 'card9'),
        '/user/stamps/m1',
      );
    });

    test('url/external target has no in-app route', () {
      expect(
        MerchantFeedCreateService.ctaRouteFor(merchantId: mid, linkType: 'url', targetId: ''),
        '',
      );
    });

    test('legacy feedPost target keeps working', () {
      expect(
        MerchantFeedCreateService.ctaRouteFor(merchantId: mid, linkType: 'feedPost', targetId: 'p7'),
        '/user/feed/p7',
      );
      expect(
        MerchantFeedCreateService.ctaRouteFor(merchantId: mid, linkType: 'feedPost', targetId: ''),
        '',
      );
    });

    test('none / unknown target → empty', () {
      expect(MerchantFeedCreateService.ctaRouteFor(merchantId: mid, linkType: 'none', targetId: ''), '');
    });
  });

  group('MerchantFeedPostData', () {
    MerchantFeedPostData parse(Map<String, dynamic> map) =>
        MerchantFeedPostData.fromMap({'postId': 'x', ...map});

    test('status derives from flags (archived > scheduled > paused > published)', () {
      expect(parse({'isArchived': true, 'isActive': true}).status, MerchantPostStatus.archived);
      expect(parse({'isScheduled': true, 'isActive': false}).status, MerchantPostStatus.scheduled);
      expect(parse({'isActive': false}).status, MerchantPostStatus.paused);
      expect(parse({'isActive': true}).status, MerchantPostStatus.published);
    });

    test('reads stamp-ad type, linkedCardId and CTA target fields', () {
      final post = parse({
        'type': 'stampAd',
        'linkedCardId': 'card1',
        'ctaLabel': 'In Wallet sammeln',
        'ctaLinkType': 'profile',
      });
      expect(post.isStampAd, isTrue);
      expect(post.linkedCardId, 'card1');
      expect(post.hasButton, isTrue);
      expect(post.ctaLinkType, 'profile');
    });

    test('legacy buttonText/buttonActionType still map to CTA', () {
      final post = parse({'buttonText': 'Mehr', 'buttonActionType': 'external', 'buttonLink': 'https://x.de'});
      expect(post.ctaLabel, 'Mehr');
      expect(post.ctaLinkType, 'external');
      expect(post.ctaUrl, 'https://x.de');
      expect(post.hasButton, isTrue);
    });

    test('no button when label empty', () {
      expect(parse({'title': 'Hi'}).hasButton, isFalse);
    });
  });

  group('FeedPostModel new fields (backward-compatible)', () {
    test('reads linkedCardId and stampCard CTA, roundtrips through toMap', () {
      final post = FeedPostModel.fromMap({
        'postId': 'p1',
        'merchantId': 'm1',
        'type': 'stampAd',
        'linkedCardId': 'card1',
        'ctaLabel': 'Zur Karte',
        'ctaLinkType': 'stampCard',
        'ctaTargetId': 'card1',
      });
      expect(post.linkedCardId, 'card1');
      expect(post.effectiveCtaType, 'stampCard');
      expect(post.effectiveButtonText, 'Zur Karte');
      expect(post.toMap()['linkedCardId'], 'card1');
    });

    test('old posts without new fields still parse (null linkedCardId)', () {
      final post = FeedPostModel.fromMap({'postId': 'p1', 'merchantId': 'm1', 'title': 'Hi'});
      expect(post.linkedCardId, isNull);
      expect(post.hasButton, isFalse);
    });
  });
}
