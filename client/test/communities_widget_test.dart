import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/communities_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/product_scope.dart';

import 'directory_widget_test.dart' show DirectoryFixture;

class CommunityFixture extends DirectoryFixture {
  bool failCommunities = false;
  Completer<void>? gate;
  final publicCommunities = <Map<String, dynamic>>[
    {'id': 'community', 'name': 'Demo Musik', 'following': false},
  ];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'communities') {
      calls.add(path);
      if (gate != null) await gate!.future;
      if (failCommunities) throw const ApiFailure('Synthetic failure');
      return {'items': publicCommunities, 'signed_in': false};
    }
    if (path == 'home') return {'events': [], 'hero': [], 'signed_in': false};
    if (path == 'events') return {'events': [], 'series': []};
    return super.directory(path, query: query, body: body);
  }
}

Widget page(CommunityFixture api, {AppLanguage? language}) {
  final child = MaterialApp(
    theme: AccessDesign.theme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: CommunitiesPage(
          api: api,
          openAccount: () async {},
          onOrganizers: (_) {},
          onFaq: () {},
        ),
      ),
    ),
  );
  return language == null
      ? child
      : LanguageScope(language: language, child: child);
}

void main() {
  testWidgets(
    'community navigation filters organizers and direct navigation clears filter',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = CommunityFixture();
      await tester.pumpWidget(
        CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
      );
      await tester.pumpAndSettle();
      final header = find.byType(AccessHeader);
      await tester.tap(
        find.descendant(of: header, matching: find.text('Communities')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Öffentliche Communities'), findsOneWidget);
      expect(find.text('Demo Musik'), findsOneWidget);
      expect(find.textContaining('Namensidee:'), findsNWidgets(48));
      if (!ProductScope.extended) expect(find.text('Folgen'), findsNothing);
      final open = find.text('Veranstalter ansehen');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(api.calls.last, contains('community: community'));
      await tester.ensureVisible(header);
      await tester.tap(
        find.descendant(of: header, matching: find.text('Programm')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: header, matching: find.text('Veranstalter')),
      );
      await tester.pumpAndSettle();
      expect(api.calls.last, isNot(contains('community: community')));
      expect(api.bodies, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search distinguishes listed communities from editorial name ideas in both languages',
    (tester) async {
      final api = CommunityFixture();
      final language = AppLanguage();
      addTearDown(language.dispose);
      await tester.pumpWidget(page(api, language: language));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nachtschicht');
      await tester.pumpAndSettle();
      expect(find.text('Demo Musik'), findsNothing);
      expect(find.text('Namensidee: Nachtschicht'), findsOneWidget);
      expect(find.textContaining('Namensidee:'), findsOneWidget);
      language.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Name idea: Nachtschicht'), findsOneWidget);
      expect(find.text('Clubbing & electronic music'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no matching fixture');
      await tester.pumpAndSettle();
      expect(find.textContaining('Name idea:'), findsNothing);
      expect(
        find.text('No matching topics. Try another search term.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Musik'), findsOneWidget);
      expect(find.textContaining('Name idea:'), findsNWidgets(48));
      expect(api.calls.where((c) => c == 'communities'), hasLength(1));
    },
  );

  testWidgets('loading and retry preserve the independent topic catalogue', (
    tester,
  ) async {
    final api = CommunityFixture()
      ..gate = Completer<void>()
      ..failCommunities = true;
    await tester.pumpWidget(page(api));
    await tester.pump();
    expect(find.text('Communities werden geladen …'), findsOneWidget);
    expect(find.textContaining('Namensidee:'), findsNWidgets(48));
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Öffentliche Communities sind derzeit nicht verfügbar.'),
      findsOneWidget,
    );
    api.failCommunities = false;
    api.gate = null;
    final retry = find.text('Erneut laden');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Demo Musik'), findsOneWidget);
    expect(
      find.text('Öffentliche Communities sind derzeit nicht verfügbar.'),
      findsNothing,
    );
  });

  testWidgets(
    'empty public directory does not present editorial examples as members',
    (tester) async {
      final api = CommunityFixture();
      api.publicCommunities.clear();
      await tester.pumpWidget(page(api));
      await tester.pumpAndSettle();
      expect(
        find.text('Noch keine öffentlich freigegebenen Communities.'),
        findsOneWidget,
      );
      expect(find.text('Veranstalter ansehen'), findsNothing);
      expect(find.textContaining('Namensidee:'), findsNWidgets(48));
      expect(api.bodies, isEmpty);
    },
  );
}
