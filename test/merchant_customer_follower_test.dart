import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/features/merchant/customers/models/merchantCustomerModel.dart';

void main() {
  group('MerchantCustomerModel follower mapping', () {
    test('isFollower from usedSystems "follower", stripped from system pills', () {
      final c = MerchantCustomerModel.fromMap({
        'id': 'u1',
        'firstName': 'Max',
        'lastName': 'Muster',
        'usedSystems': ['follower', 'stampCards'],
        'followedAt': '2026-06-20T10:00:00.000Z',
      });
      expect(c.isFollower, isTrue);
      expect(c.usedSystems, ['stampCards']); // 'follower' removed from pills
      expect(c.name, 'Max Muster');
      expect(c.followedAt, isNotNull);
    });

    test('isFollower from explicit flag even without systems', () {
      final c = MerchantCustomerModel.fromMap({'uid': 'u2', 'isFollower': true});
      expect(c.isFollower, isTrue);
      expect(c.usedSystems, isEmpty);
    });

    test('interests merge origins + categories, de-duplicated', () {
      final c = MerchantCustomerModel.fromMap({
        'id': 'u3',
        'interestOrigins': ['Italienisch', 'Türkisch'],
        'interestCategories': ['Türkisch', 'Vegan'],
      });
      expect(c.interests, ['Italienisch', 'Türkisch', 'Vegan']);
    });

    test('followedAt falls back to joinedAt; photo + postalCode read', () {
      final c = MerchantCustomerModel.fromMap({
        'id': 'u4',
        'isFollower': true,
        'joinedAt': '2026-06-21T08:00:00.000Z',
        'profileImageUrl': 'https://x/pic.jpg',
        'postalCode': '60325',
      });
      expect(c.followedAt, isNotNull);
      expect(c.profileImageUrl, 'https://x/pic.jpg');
      expect(c.postalCode, '60325');
    });

    test('non-follower customer with no systems stays empty + not follower', () {
      final c = MerchantCustomerModel.fromMap({'id': 'u5', 'name': 'Gast'});
      expect(c.isFollower, isFalse);
      expect(c.usedSystems, isEmpty);
      expect(c.interests, isEmpty);
    });
  });
}
