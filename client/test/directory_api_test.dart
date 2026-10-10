import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/access_api.dart';

void main() {
  test(
    'directory reuses signed session, encodes search and clears expired token',
    () async {
      final requests = <http.Request>[];
      final api = BetterAuthAccessApi(
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/sign-in/email')) {
            return http.Response(
              '{}',
              200,
              headers: {'set-auth-token': 'signed-fixture'},
            );
          }
          if (r.url.path.endsWith('/manage')) {
            return http.Response('{"code":"UNAUTHENTICATED"}', 401);
          }
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );
      await api.directory('organizers', query: {'q': 'A & B'});
      expect(requests.last.headers.containsKey('Authorization'), false);
      expect(requests.last.url.queryParameters['q'], 'A & B');
      await api.login('guest.a@example.invalid', 'Synthetic-2026!');
      await api.directory('organizers');
      expect(requests.last.headers['Authorization'], 'Bearer signed-fixture');
      await expectLater(
        api.directory('manage'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.unauthenticated,
            'unauthenticated',
            true,
          ),
        ),
      );
      await api.directory('venues');
      expect(requests.last.headers.containsKey('Authorization'), false);
      api.close();
    },
  );
  test(
    'directory errors are fixed German messages rather than server data',
    () async {
      final api = BetterAuthAccessApi(
        client: MockClient(
          (_) async => http.Response(
            '{"code":"FORM_CHANGED","private":"hidden fixture"}',
            409,
          ),
        ),
      );
      await expectLater(
        api.directory('organizers/a/apply', body: {}),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'safe message',
            contains('Formular wurde geändert'),
          ),
        ),
      );
      api.close();
    },
  );
}
