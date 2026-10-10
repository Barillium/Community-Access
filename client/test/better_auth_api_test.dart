import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/better_auth_api.dart';

void main() {
  test('Flutter adopts signed header, not raw body token; recovery secrets stay in bodies', () async {
    final requests = <http.Request>[];
    final api = BetterAuthAccessApi(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.url.path == '/api/account/me'
                ? {
                    'user': {'email': 'auth@example.invalid'},
                  }
                : {'token': 'unsigned-body-token'},
          ),
          200,
          headers: {'set-auth-token': 'signed-synthetic-token'},
        );
      }),
    );
    await api.login(' AUTH@EXAMPLE.INVALID ', 'Synthetic-2026!');
    expect(requests.last.url.path, '/api/auth/sign-in/email');
    expect(jsonDecode(requests.last.body)['email'], 'auth@example.invalid');
    await api.snapshot();
    expect(
      requests.last.headers['authorization'],
      'Bearer signed-synthetic-token',
    );
    await api.resendVerification();
    expect(requests.last.url.path, '/api/auth/send-verification-email');
    expect(jsonDecode(requests.last.body), {'email': 'auth@example.invalid'});
    await api.verifyEmail('auth@example.invalid', 'a' * 64);
    await api.resetPassword(
      'auth@example.invalid',
      'b' * 64,
      'Changed-2026!',
      'Changed-2026!',
    );
    await api.snapshot();
    expect(requests.last.headers.containsKey('authorization'), false);
    for (final request in requests) {
      expect(request.url.query, isEmpty);
    }
    api.close();
  });

  test(
    'expired server session clears bearer and provides a bounded error',
    () async {
      final seen = <http.Request>[];
      final api = BetterAuthAccessApi(
        client: MockClient((request) async {
          seen.add(request);
          return request.url.path == '/api/auth/sign-in/email'
              ? http.Response(
                  '{}',
                  200,
                  headers: {'set-auth-token': 'signed-token'},
                )
              : http.Response('private response with synthetic token', 401);
        }),
      );
      await api.login('auth@example.invalid', 'Synthetic-2026!');
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          api.snapshot(),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.unauthenticated,
              'session expired',
              true,
            ),
          ),
        );
      }
      expect(seen.last.headers.containsKey('authorization'), false);
      api.close();
    },
  );

  test(
    'missing signed session cannot be mistaken for successful login',
    () async {
      final api = BetterAuthAccessApi(
        client: MockClient((_) async => http.Response('{"token":"raw"}', 200)),
      );
      await expectLater(
        api.login('auth@example.invalid', 'Synthetic-2026!'),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(api.location(1), throwsA(isA<ApiFailure>()));
      api.close();
    },
  );

  test('remote endpoints are rejected', () {
    expect(
      () => BetterAuthAccessApi(baseUrl: 'https://example.invalid'),
      throwsArgumentError,
    );
  });

  test('rate limits show bounded retry advice and preserve the signed session without replaying writes', () async {
    final seen = <http.Request>[];
    var limited = true;
    final api = BetterAuthAccessApi(
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/api/auth/sign-in/email') {
          return http.Response(
            '{}',
            200,
            headers: {'set-auth-token': 'signed-synthetic-token'},
          );
        }
        return limited
            ? http.Response(
                'private provider details',
                429,
                headers: {'retry-after': '17'},
              )
            : http.Response('{"user":{"email":"auth@example.invalid"}}', 200);
      }),
    );
    await api.login('auth@example.invalid', 'Synthetic-2026!');
    await expectLater(
      api.access('synthetic', body: {}),
      throwsA(
        isA<ApiFailure>()
            .having(
              (e) => e.message,
              'retry message',
              'Zu viele Anfragen. Bitte warte 17 Sekunden und versuche es erneut.',
            )
            .having((e) => e.unauthenticated, 'keeps session', false),
      ),
    );
    expect(seen.where((r) => r.url.path == '/api/access/synthetic').length, 1);
    limited = false;
    await api.snapshot();
    expect(seen.last.headers['authorization'], 'Bearer signed-synthetic-token');
    api.close();
  });

  test('malformed retry headers never become user-facing content', () async {
    for (final header in ['private token', '-5', '9999999']) {
      final api = BetterAuthAccessApi(
        client: MockClient(
          (_) async => http.Response(
            'private response',
            429,
            headers: {'retry-after': header},
          ),
        ),
      );
      await expectLater(
        api.login('auth@example.invalid', 'Synthetic-2026!'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'safe message',
            'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.',
          ),
        ),
      );
      api.close();
    }
  });
}
