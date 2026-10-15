import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/event_editorial_view.dart';

void main() {
  final base = Uri.parse('https://development.example.test/#event');
  const path = '/event-media/0123456789abcdefabcd.webp';
  test(
    'catalog image stays on the current origin and discards page fragments',
    () {
      expect(
        sameOriginEventMedia(path, base).toString(),
        'https://development.example.test$path',
      );
    },
  );
  test(
    'external URLs, traversal, query strings and non-web bases are rejected',
    () {
      for (final value in [
        'https://tracker.example.test$path',
        '//tracker.example.test$path',
        '$path?token=private',
        '$path#fragment',
        '/event-media/../private.webp',
        'data:image/webp;base64,abcd',
        '/event-media/not-hashed.webp',
      ]) {
        expect(sameOriginEventMedia(value, base), isNull);
      }
      expect(sameOriginEventMedia(path, Uri.parse('file:///tmp/app')), isNull);
      expect(
        sameOriginEventMedia(path, Uri.parse('https://user:pass@example.test')),
        isNull,
      );
    },
  );
}
