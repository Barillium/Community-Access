import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/account_registration_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/main.dart';

import 'auth_account_widget_test.dart' show AuthAccountApi;

class PublicSearchApi extends AuthAccountApi implements DirectoryApi {
  final queries = <Map<String, String>>[];
  final slow = Completer<Map<String, dynamic>>();
  bool failed = false;

  Map<String, dynamic> result(
    String title, {
    bool more = false,
    int page = 1,
  }) => {
    'series': [],
    'events': [
      {
        'id': '00000000-0000-4000-8000-000000000003',
        'title': title,
        'status': 'published',
        'starts_at': null,
        'location': '',
      },
    ],
    'page': page,
    'has_more': more,
  };

  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path != 'events') throw const ApiFailure('Nicht verfügbar.');
    queries.add(Map.of(query!));
    if (failed) {
      throw const ApiFailure('Der öffentliche Katalog ist nicht erreichbar.');
    }
    if (query['q'] == 'slow') return slow.future;
    if (query['q'] == 'empty') {
      return {'series': [], 'events': [], 'has_more': false};
    }
    final page = int.parse(query['page']!);
    return result('Demo Suchergebnis $page', more: page == 1, page: page);
  }
}

void main() {
  testWidgets('search submits through button and keyboard, pages and resets', (
    tester,
  ) async {
    final api = PublicSearchApi();
    await tester.pumpWidget(
      CommunityAccessApp(api: api, showPublicHome: true, authOnly: true),
    );
    await tester.pumpAndSettle();
    expect(api.queries.single, {'q': '', 'page': '1', 'scope': 'upcoming'});
    expect(find.text('Demo Suchergebnis 1'), findsOneWidget);
    await tester.ensureVisible(find.text('Weitere Veranstaltungen'));
    await tester.tap(find.text('Weitere Veranstaltungen'));
    await tester.pumpAndSettle();
    expect(api.queries.last['page'], '2');
    expect(find.text('Demo Suchergebnis 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Demo Musik  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(api.queries.last, {
      'q': 'Demo Musik',
      'page': '1',
      'scope': 'upcoming',
    });
    await tester.ensureVisible(find.text('Suche zurücksetzen'));
    await tester.tap(find.text('Suche zurücksetzen'));
    await tester.pumpAndSettle();
    expect(api.queries.last, {'q': '', 'page': '1', 'scope': 'upcoming'});
    await tester.enterText(find.byType(TextField), 'empty');
    await tester.ensureVisible(find.text('Suchen'));
    await tester.tap(find.text('Suchen'));
    await tester.pumpAndSettle();
    expect(find.text('Keine passenden öffentlichen Events.'), findsOneWidget);
    expect(find.text('Demo Suchergebnis 1'), findsNothing);
  });

  testWidgets(
    'older responses cannot replace current results; failure clears results and can retry',
    (tester) async {
      final api = PublicSearchApi();
      await tester.pumpWidget(
        CommunityAccessApp(api: api, showPublicHome: true),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'slow');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'empty');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      api.slow.complete(api.result('Veraltetes Demo-Ergebnis'));
      await tester.pumpAndSettle();
      expect(find.text('Veraltetes Demo-Ergebnis'), findsNothing);
      expect(find.text('Keine passenden öffentlichen Events.'), findsOneWidget);
      api.failed = true;
      await tester.enterText(find.byType(TextField), 'Demo');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        find.text('Der öffentliche Katalog ist nicht erreichbar.'),
        findsOneWidget,
      );
      expect(find.text('Demo Suchergebnis 1'), findsNothing);
      api.failed = false;
      await tester.ensureVisible(find.text('Erneut versuchen'));
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Suchergebnis 1'), findsOneWidget);
    },
  );

  testWidgets('information remains reachable and explicitly incomplete', (
    tester,
  ) async {
    await tester.pumpWidget(
      CommunityAccessApp(api: AuthAccountApi(), showPublicHome: true),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Betreiber / Impressum'));
    await tester.tap(find.text('Betreiber / Impressum'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Die ladungsfähige Anschrift'), findsOneWidget);
    expect(find.textContaining('unvollständiger Entwurf'), findsOneWidget);
    expect(find.textContaining('info@communityaccess.de'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Datenschutz'));
    await tester.tap(find.text('Datenschutz'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unvollständiger Entwurf'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hilfe & Kontakt'));
    await tester.tap(find.text('Hilfe & Kontakt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('info@communityaccess.de'), findsOneWidget);
    expect(find.text('E-Mail schreiben'), findsOneWidget);
  });

  testWidgets(
    'registration validation wraps completely at 320 pixels and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AccountRegistrationPage(api: AuthAccountApi()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Testkonto anlegen'));
      await tester.tap(find.text('Testkonto anlegen'));
      await tester.pumpAndSettle();
      for (final text in [
        'Trage einen erfundenen Namen ein.',
        'Verwende eine Adresse mit @example.invalid.',
        'Verwende 12 bis 72 Zeichen und höchstens 72 UTF-8-Bytes.',
      ]) {
        final error = find.text(text);
        expect(error, findsOneWidget);
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(error);
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        expect(paragraph.size.width, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
