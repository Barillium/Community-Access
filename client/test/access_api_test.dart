import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/access_api.dart';

void main() {
  test('invitation secrets stay in POST bodies and registration adopts only returned auth token', () async {
    final calls = <http.Request>[];
    final api = HttpAccessApi(
      client: MockClient((request) async {
        calls.add(request);
        return http.Response(
          jsonEncode(
            request.url.path == '/api/register'
                ? {'token': 'new-synthetic-token'}
                : {'community': 'Synthetic'},
          ),
          200,
        );
      }),
    );
    final invitation = 'a' * 64;
    await api.invitation(invitation);
    expect(calls.last.method, 'POST');
    expect(calls.last.url.query, isEmpty);
    expect(calls.last.url.path, '/api/invitations/preview');
    expect(jsonDecode(calls.last.body), {'invitation': invitation});
    await api.register(
      invitation,
      'Synthetic',
      'test@example.invalid',
      'synthetic-password',
      'synthetic-password',
    );
    await api.snapshot();
    expect(calls.last.headers['Authorization'], 'Bearer new-synthetic-token');
    await api.apply(invitation, 7, {'q1': 'Synthetic answer'});
    expect(calls.last.url.path, '/api/applications');
    expect(calls.last.url.query, isEmpty);
    expect(jsonDecode(calls.last.body), {
      'invitation': invitation,
      'form_id': 7,
      'answers': {'q1': 'Synthetic answer'},
    });
    expect(calls.last.headers['Authorization'], 'Bearer new-synthetic-token');
    await api.withdrawApplication(1);
    expect(jsonDecode(calls.last.body), {'confirm_withdraw': true});
    api.close();
  });
  test(
    'API retains bearer token in memory and sends accepted age acknowledgement',
    () async {
      final calls = <http.Request>[];
      final api = HttpAccessApi(
        client: MockClient((request) async {
          calls.add(request);
          if (request.url.path == '/api/login') {
            return http.Response(jsonEncode({'token': 'synthetic-token'}), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await api.login(' GUEST.A@EXAMPLE.INVALID ', 'synthetic-password');
      expect(jsonDecode(calls.last.body)['email'], 'guest.a@example.invalid');
      await api.requestEvent(1);
      expect(calls.last.headers['Authorization'], 'Bearer synthetic-token');
      expect(jsonDecode(calls.last.body), {'age_confirmed': true});
      await api.logout();
      await api.snapshot();
      expect(calls.last.headers.containsKey('Authorization'), false);
      api.close();
    },
  );
  test('denied location gives a bounded error without returning private response body', () async {
    final api = HttpAccessApi(
      client: MockClient(
        (_) async => http.Response('private synthetic response', 403),
      ),
    );
    await expectLater(
      api.location(1),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          'Für diese Aktion fehlt die aktuelle Berechtigung.',
        ),
      ),
    );
    api.close();
  });
  test('remote API configuration is rejected', () {
    expect(
      () => HttpAccessApi(baseUrl: 'https://example.invalid'),
      throwsArgumentError,
    );
  });
}
