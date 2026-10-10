import 'dart:async';

import 'field_finder.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/access_flow_api.dart';
import 'package:community_access_client/access_flow_page.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/directory_api.dart';

class FlowApi extends HttpAccessApi implements AccessFlowApi {
  bool submitted = false;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> snapshot() async => {
    'organizer_applications': submitted
        ? [
            {'id': '00000000-0000-4000-8000-000000000001', 'status': 'pending'},
          ]
        : [],
    'applications': [],
    'memberships': [],
    'events': [],
    'moderated_communities': [],
    'is_team': false,
  };
  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add(path);
    if (path == 'organizer-applications') {
      if (body?['awareness_concept'] is! bool ||
          body?['awareness_team'] is! bool) {
        throw const ApiFailure('Awarenessangaben fehlen.');
      }
      submitted = true;
    }
    return {};
  }
}

class MemberFlowApi extends FlowApi implements DirectoryApi {
  String requestStatus = 'pending';
  @override
  Future<Map<String, dynamic>> snapshot() async => {
    ...await super.snapshot(),
    'events': [
      {
        'id': '00000000-0000-4000-8000-000000000005',
        'title': 'Synthetic event',
        'request_status': requestStatus,
        'confirmed': requestStatus == 'approved',
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async => {
    'signed_in': true,
    'request': {'status': requestStatus},
    'form': [],
    'method': 'manual',
    'before_start': true,
    'can_request': true,
    'can_withdraw': true,
  };
}

void main() {
  testWidgets(
    'refresh replaces the old pending attendance status after a host approval',
    (tester) async {
      final api = MemberFlowApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: AccessFlowPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anfrage in Bearbeitung'), findsOneWidget);
      api.requestStatus = 'approved';
      await tester.tap(find.byTooltip('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Teilnahme zugesagt'), findsOneWidget);
      expect(find.text('Anfrage in Bearbeitung'), findsNothing);
    },
  );
  test('a delayed response from the old session cannot return a protected location', () async {
    final delayed = Completer<http.Response>();
    final api = BetterAuthAccessApi(
      client: MockClient((r) async {
        if (r.url.path == '/api/auth/sign-in/email') {
          return http.Response(
            '{}',
            200,
            headers: {'set-auth-token': 'synthetic-signed-session'},
          );
        }
        if (r.url.path.contains('/location')) return delayed.future;
        return http.Response('{}', 200);
      }),
    );
    await api.login('guest.a@example.invalid', 'Synthetic-2026!');
    final future = api.location('00000000-0000-4000-8000-000000000002');
    final rejected = expectLater(future, throwsA(isA<ApiFailure>()));
    await api.logout();
    delayed.complete(
      http.Response(
        jsonEncode({'location': 'Synthetic protected location'}),
        200,
      ),
    );
    await rejected;
    api.close();
  });
  test('UUID invitation uses the answered form version and puts tokens only in the body', () async {
    final requests = <http.Request>[];
    final api = BetterAuthAccessApi(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/preview')) {
          return http.Response(
            jsonEncode({
              'community_id': '00000000-0000-4000-8000-000000000003',
              'form': {
                'id': '00000000-0000-4000-8000-000000000003',
                'version': 7,
                'questions': [
                  {
                    'key': 'q0',
                    'label': 'Synthetic question',
                    'required': true,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'set-auth-token': 'synthetic-signed-session'},
        );
      }),
    );
    await api.login('guest.a@example.invalid', 'Synthetic-2026!');
    final invitation = await api.invitation('a' * 64);
    await api.apply('a' * 64, invitation['form']['id'] as String, {
      'q0': 'Synthetic answer',
    });
    expect(jsonDecode(requests.last.body)['version'], 7);
    expect(requests.every((r) => r.url.query.isEmpty), true);
    await expectLater(
      api.apply('a' * 64, invitation['form']['id'] as String, {}),
      throwsA(isA<ApiFailure>()),
    );
    api.close();
  });
  testWidgets(
    'organizer submission requires explicit awareness answers and never exposes team controls',
    (tester) async {
      final api = FlowApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: AccessFlowPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Teamprüfung'), findsNothing);
      await tester.tap(find.text('Veranstalteraufnahme').first);
      await tester.pumpAndSettle();
      final submit = find.text('Veranstalterbewerbung einreichen');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submitted, false);
      for (final entry in {
        'Name des Kollektivs': 'Demo Kollektiv',
        'Selbstdarstellung': 'Synthetische Beschreibung',
        'Veranstaltungstypen': 'Musik',
      }.entries) {
        final f = fieldWithLabel(TextFormField, entry.key);
        await tester.ensureVisible(f);
        await tester.enterText(f, entry.value);
      }
      final dropdowns = find.byType(DropdownButtonFormField<bool>);
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(dropdowns.at(i));
        await tester.tap(dropdowns.at(i));
        await tester.pumpAndSettle();
        await tester.tap(find.text(i == 0 ? 'Ja' : 'Nein').last);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submitted, true);
      expect(find.text('In Bearbeitung'), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.close();
    },
  );
  testWidgets('access pages remain usable at 320 pixels with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FlowApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AccessFlowPage(api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Veranstalteraufnahme').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    api.close();
  });
}
