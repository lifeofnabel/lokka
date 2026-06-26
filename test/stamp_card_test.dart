import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';

void main() {
  group('StampCardModel reward tiers', () {
    test('legacy single reward synthesises one tier at requiredStamps', () {
      final card = StampCardModel.empty(merchantId: 'm1').copyWith(
        requiredStamps: 10,
        rewardType: StampRewardType.custom,
        rewardTitle: 'Free coffee',
      );
      final tiers = card.effectiveRewardTiers;
      expect(tiers.length, 1);
      expect(tiers.first.atStamp, 10);
      expect(tiers.first.label, 'Free coffee');
      expect(card.maxStamps, 10);
    });

    test('tiered rewards are returned sorted ascending', () {
      final card = StampCardModel.empty(merchantId: 'm1').copyWith(
        requiredStamps: 10,
        rewardTiers: const [
          StampRewardTier(atStamp: 10, type: 'free', label: 'Free'),
          StampRewardTier(atStamp: 5, type: 'discount', label: '10% off'),
        ],
      );
      final tiers = card.effectiveRewardTiers;
      expect(tiers.map((t) => t.atStamp).toList(), [5, 10]);
      expect(card.maxStamps, 10);
    });

    test('maxStamps follows the highest tier when it exceeds requiredStamps', () {
      final card = StampCardModel.empty(merchantId: 'm1').copyWith(
        requiredStamps: 8,
        rewardTiers: const [
          StampRewardTier(atStamp: 12, type: 'free', label: 'Big'),
        ],
      );
      expect(card.maxStamps, 12);
    });

    test('toMap/fromMap round-trips tiers and stick binding', () {
      final card = StampCardModel.empty(merchantId: 'm1').copyWith(
        title: 'Coffee',
        boundStickId: '04a1b2c3',
        rewardTiers: const [
          StampRewardTier(atStamp: 5, type: 'discount', label: '10% off'),
          StampRewardTier(atStamp: 10, type: 'free', label: 'Free'),
        ],
      );
      final restored = StampCardModel.fromMap(card.toMap());
      expect(restored.boundStickId, '04a1b2c3');
      expect(restored.hasStick, isTrue);
      expect(restored.rewardTiers.length, 2);
      expect(restored.rewardTiers.first.atStamp, 5);
      expect(restored.rewardTiers.last.label, 'Free');
    });

    test('hasStick is false without a binding', () {
      final card = StampCardModel.empty(merchantId: 'm1');
      expect(card.hasStick, isFalse);
      expect(card.effectiveRewardTiers, isNotEmpty);
    });
  });
}
