import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/social_login_panel.dart';

import 'auth_account_widget_test.dart' show AuthAccountApi;

class SocialFixtureApi extends AuthAccountApi implements SocialAuthApi {
  List<String> providers = ['google', 'apple', 'facebook'];
  String? selected;
  bool linking = false;
  int completed = 0;
  bool failCompletion = false;
  @override
  Future<List<String>> socialProviders() async => providers;
  @override
  Future<Uri> startSocial(String provider, {bool link = false}) async {
    selected = provider;
    linking = link;
    return Uri.parse('https://accounts.google.com/synthetic');
  }

  @override
  Future<void> completeSocial() async {
    completed++;
    if (failCompletion) {
      throw const ApiFailure(
        'Die Anbieteranmeldung konnte nicht abgeschlossen werden.',
      );
    }
  }
}

void main() {
  test('provider order and validated destinations; signed session comes only from header', () async {
    final seen = <http.Request>[];
    final api = BetterAuthAccessApi(
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path.endsWith('/providers')) {
          return http.Response(
            '{"providers":["facebook","google","apple"]}',
            200,
          );
        }
        if (request.url.path.endsWith('/start')) {
          final provider = jsonDecode(request.body)['provider'];
          const hosts = {
            'google': 'accounts.google.com',
            'apple': 'appleid.apple.com',
            'facebook': 'www.facebook.com',
          };
          return http.Response(
            jsonEncode({'url': 'https://${hosts[provider]}/synthetic'}),
            200,
          );
        }
        return http.Response(
          '{"authenticated":true,"token":"unsigned"}',
          200,
          headers: {'set-auth-token': 'signed-synthetic'},
        );
      }),
    );
    expect(await api.socialProviders(), ['google', 'apple', 'facebook']);
    for (final id in ['google', 'apple', 'facebook']) {
      expect((await api.startSocial(id)).scheme, 'https');
      expect(jsonDecode(seen.last.body), {'provider': id, 'link': false});
    }
    await api.completeSocial();
    await api.snapshot();
    expect(seen.last.headers['authorization'], 'Bearer signed-synthetic');
    expect(seen.every((r) => r.url.query.isEmpty), true);
    api.close();
  });
  test('redirect host/port/credentials and provider errors fail without exposing upstream details', () async {
    for (final url in [
      'http://accounts.google.com',
      'https://attacker.example.invalid',
      'https://user:private@accounts.google.com',
      'https://accounts.google.com:8443',
    ]) {
      final api = BetterAuthAccessApi(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'url': url}), 200),
        ),
      );
      await expectLater(api.startSocial('google'), throwsA(isA<ApiFailure>()));
      api.close();
    }
    final api = BetterAuthAccessApi(
      client: MockClient(
        (_) async => http.Response(
          '{"code":"SOCIAL_REAUTH_REQUIRED","detail":"private-provider-token"}',
          403,
        ),
      ),
    );
    await expectLater(
      api.startSocial('google', link: true),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'bounded error',
          isNot(contains('private')),
        ),
      ),
    );
    api.close();
  });
  test('a callback URL alone cannot authenticate; missing signed handoff is rejected', () async {
    expect(
      socialResult(Uri.parse('https://app.example.invalid/#social=success')),
      'success',
    );
    expect(
      socialResult(Uri.parse('https://app.example.invalid/?social=success')),
      isNull,
    );
    expect(
      socialResult(
        Uri.parse('https://app.example.invalid/#social=success&token=forged'),
      ),
      isNull,
    );
    final api = BetterAuthAccessApi(
      client: MockClient(
        (_) async => http.Response('{"token":"unsigned"}', 200),
      ),
    );
    await expectLater(api.completeSocial(), throwsA(isA<ApiFailure>()));
    api.close();
  });
  testWidgets(
    'three accessible buttons remain usable at 320px and twice normal text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final api = SocialFixtureApi();
      Uri? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SocialLoginPanel(
                  api: api,
                  navigate: (url) {
                    destination = url;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final google = find.text('Mit Google anmelden'),
          apple = find.text('Mit Apple anmelden'),
          facebook = find.text('Mit Facebook anmelden');
      expect(
        tester.getTopLeft(google).dy,
        lessThan(tester.getTopLeft(apple).dy),
      );
      expect(
        tester.getTopLeft(apple).dy,
        lessThan(tester.getTopLeft(facebook).dy),
      );
      expect(
        tester
            .getSemantics(
              find.widgetWithText(OutlinedButton, 'Mit Google anmelden'),
            )
            .label,
        contains('Mit Google anmelden'),
      );
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pumpAndSettle();
      expect(api.selected, 'google');
      expect(destination?.host, 'accounts.google.com');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'disabled/unconfigured providers never render misleading login buttons',
    (tester) async {
      final api = SocialFixtureApi()..providers = [];
      await tester.pumpWidget(MaterialApp(home: SocialLoginPanel(api: api)));
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsNothing);
    },
  );
  testWidgets(
    'successful social return checks server session before showing account; failure stays signed out',
    (tester) async {
      final api = SocialFixtureApi();
      await tester.pumpWidget(
        CommunityAccessApp(
          api: api,
          authOnly: true,
          initialSocialResult: 'success',
        ),
      );
      await tester.pumpAndSettle();
      expect(api.completed, 1);
      expect(find.text('Dein Konto.'), findsOneWidget);
      expect(find.text('Google verbinden'), findsOneWidget);
      expect(find.text('Eventteilnahme anfragen'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final failed = SocialFixtureApi()..failCompletion = true;
      await tester.pumpWidget(
        CommunityAccessApp(
          api: failed,
          authOnly: true,
          initialSocialResult: 'success',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dein Konto.'), findsNothing);
      expect(find.text('Anmelden'), findsOneWidget);
    },
  );
}
