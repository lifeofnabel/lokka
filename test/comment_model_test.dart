import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/features/user/feed/models/commentModel.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';

void main() {
  group('CommentModel', () {
    test('round-trips through fromMap with the doc id injected', () {
      final c = CommentModel.fromMap({
        'commentId': 'c1',
        'postId': 'p1',
        'userId': 'u1',
        'userName': 'Sam',
        'text': 'Lecker!',
      });
      expect(c.commentId, 'c1');
      expect(c.postId, 'p1');
      expect(c.userId, 'u1');
      expect(c.userName, 'Sam');
      expect(c.text, 'Lecker!');
    });

    test('tolerates missing fields without throwing', () {
      final c = CommentModel.fromMap(const {});
      expect(c.commentId, '');
      expect(c.userName, '');
      expect(c.text, '');
      expect(c.createdAt, isNull);
    });
  });

  group('FeedPostModel.commentsCount', () {
    test('parses an int counter', () {
      final post = FeedPostModel.fromMap({
        'postId': 'p1',
        'merchantId': 'm1',
        'commentsCount': 7,
      });
      expect(post.commentsCount, 7);
    });

    test('defaults to 0 when absent and survives toMap', () {
      final post = FeedPostModel.fromMap({'postId': 'p1'});
      expect(post.commentsCount, 0);
      expect(post.toMap()['commentsCount'], 0);
    });
  });
}
