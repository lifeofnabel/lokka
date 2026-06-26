import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/features/user/wallet/utils/walletCode.dart';

void main() {
  group('WalletCode — the store↔user code spine', () {
    test('format is Letter+3digits+Letter+3digits', () {
      for (var i = 0; i < 500; i++) {
        final code = WalletCode.generate('seed-$i');
        expect(code.length, 8, reason: code);
        expect(WalletCode.isValid(code), isTrue, reason: code);
      }
    });

    test('letters never use the ambiguous I or O (dictatable)', () {
      // Exhaustively cover the letter set: every letter that can appear must be
      // in the safe alphabet (no I, no O).
      expect(WalletCode.letters.contains('I'), isFalse);
      expect(WalletCode.letters.contains('O'), isFalse);
      for (var i = 0; i < 2000; i++) {
        final code = WalletCode.generate('store|user|$i');
        final l1 = code[0];
        final l2 = code[4];
        expect(WalletCode.letters.contains(l1), isTrue, reason: code);
        expect(WalletCode.letters.contains(l2), isTrue, reason: code);
        expect(l1, isNot('I'));
        expect(l1, isNot('O'));
        expect(l2, isNot('I'));
        expect(l2, isNot('O'));
      }
    });

    test('deterministic — same seed yields same code', () {
      final a = WalletCode.generate('uid123|merchantABC');
      final b = WalletCode.generate('uid123|merchantABC');
      expect(a, b);
    });

    test('salt produces a different code (collision regeneration)', () {
      final base = WalletCode.generate('uid|mid', salt: 0);
      final salted = WalletCode.generate('uid|mid', salt: 1);
      expect(base, isNot(salted));
    });

    test('pretty inserts a dash: A123B456 -> A123-B456', () {
      final code = WalletCode.generate('any-seed');
      final pretty = WalletCode.pretty(code);
      expect(pretty.length, 9);
      expect(pretty[4], '-');
      expect(pretty.replaceAll('-', ''), code);
    });

    test('pretty leaves legacy/odd codes untouched', () {
      expect(WalletCode.pretty('BO-12345'), 'BO-12345');
      expect(WalletCode.pretty(''), '');
    });

    test('isValid rejects malformed codes', () {
      expect(WalletCode.isValid('A12B456'), isFalse); // too short
      expect(WalletCode.isValid('AI23B456'), isFalse); // ambiguous letter I
      expect(WalletCode.isValid('1234B456'), isFalse); // leading digit
      expect(WalletCode.isValid('A123B45'), isFalse); // too short
    });
  });
}
