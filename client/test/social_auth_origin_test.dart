import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/account_recovery_page.dart';
import 'package:community_access_client/auth_mode.dart';
import 'package:community_access_client/better_auth_api.dart';

void main() {
  test('explicit UI origin accepts recovery while refusing foreign hosts and paths', () {
    final email = privateMailMode
        ? 'fixture@example.test'
        : 'fixture@example.invalid';
    final link =
        '$authUiOrigin/#verify=${'a' * 64}&email=${Uri.encodeComponent(email)}';
    expect(accountLink(link)?.kind, 'verify');
    expect(
      accountLink(
        link.replaceFirst(authUiOrigin, 'https://foreign.example.invalid'),
      ),
      isNull,
    );
    expect(accountLink(link.replaceFirst('/#', '/other#')), isNull);
    expect(accountLink(link.replaceFirst('/#', '/?tracking=true#')), isNull);
  });
  test(
    'only compiled API origin receives login requests and the signed session',
    () async {
      const expected = String.fromEnvironment(
        'CA_AUTH_API_ORIGIN',
        defaultValue: 'http://127.0.0.1:8000',
      );
      final requests = <http.Request>[];
      final api = BetterAuthAccessApi(
        client: MockClient((req) async {
          requests.add(req);
          return http.Response(
            jsonEncode({'authenticated': true}),
            200,
            headers: {'set-auth-token': 'signed-synthetic'},
          );
        }),
      );
      await api.login('fixture@example.invalid', 'Synthetic-2026!');
      await api.snapshot();
      expect(requests.every((request) => request.url.origin == expected), true);
      expect(requests.last.headers['authorization'], 'Bearer signed-synthetic');
      expect(
        () => BetterAuthAccessApi(baseUrl: 'https://foreign.example.invalid'),
        throwsArgumentError,
      );
      api.close();
    },
  );
}
