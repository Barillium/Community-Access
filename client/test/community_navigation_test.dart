import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/access_brand.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/community_detail_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/resource_return.dart';

import 'directory_widget_test.dart' show DirectoryFixture;
import 'event_editorial_test.dart' show demoEvent;

const communityA = '10000000-0000-4000-8000-000000000001';
const communityB = '10000000-0000-4000-8000-000000000002';

class NavigationFixture extends DirectoryFixture {
  final eventQueries = <Map<String, String>>[];
  bool failNavigation = false;
  final listedCommunities = <Map<String, dynamic>>[
    {'id': communityA, 'name': 'Demo Musik', 'event_count': 2},
    {'id': communityB, 'name': 'Demo Atelier', 'event_count': 2},
  ];
  late final events = <Map<String, dynamic>>[
    for (var n = 0; n < 3; n++)
      {
        ...demoEvent(),
        'id': '20000000-0000-4000-8000-00000000000${n + 1}',
        'title': [
          'Demo Abend',
          'Demo Ateliertermin',
          'Demo Gemeinsamer Markt',
        ][n],
        'access_mode': 'public',
        'ticket_mode': 'none',
        'communities': [
          if (n != 1) {'id': communityA, 'name': 'Demo Musik'},
          if (n != 0) {'id': communityB, 'name': 'Demo Atelier'},
        ],
      },
  ];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    calls.add(path);
    if (body != null) bodies.add(body);
    if (path == 'home') {
      return {
        'signed_in': false,
        'events': events,
        'hero': [events.first],
        'communities': listedCommunities,
      };
    }
    if (path == 'communities') {
      if (failNavigation) throw const ApiFailure('Synthetic failure');
      return {'signed_in': false, 'items': listedCommunities};
    }
    if (path == 'events') {
      eventQueries.add({...?query});
      return {
        'events': events
            .where(
              (e) =>
                  (query?['community'] == null ||
                      (e['communities'] as List).any(
                        (c) => c['id'] == query!['community'],
                      )) &&
                  (e['title'] as String).toLowerCase().contains(
                    (query?['q'] ?? '').toLowerCase(),
                  ),
            )
            .toList(),
        'series': [],
        'page': 1,
        'has_more': false,
      };
    }
    if (path.startsWith('events/')) {
      return events.firstWhere((e) => e['id'] == path.split('/').last);
    }
    return super.directory(path, query: query, body: body);
  }
}

void main() {
  test(
    'community resource links validate identifiers without granting access',
    () {
      expect(validatedResourceTarget('community=$communityA'), {
        'kind': 'community',
        'id': communityA,
      });
      expect(validatedResourceTarget('community=private-name'), isNull);
      expect(
        validatedResourceTarget('community=$communityA&token=secret'),
        isNull,
      );
    },
  );
  testWidgets(
    'hero opens community page, global filter selects it and can clear it',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = NavigationFixture();
      await tester.pumpWidget(
        CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('community-link:$communityA')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CommunityDetailPage), findsOneWidget);
      expect(find.text('Demo Gemeinsamer Markt'), findsOneWidget);
      expect(find.text('Demo Ateliertermin'), findsNothing);
      await tester.ensureVisible(find.text('Im Programm filtern'));
      await tester.tap(find.text('Im Programm filtern'));
      await tester.pumpAndSettle();
      expect(api.eventQueries.last['community'], communityA);
      expect(find.text('Veranstaltungen'), findsOneWidget);
      expect(find.text('Demo Ateliertermin'), findsNothing);
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alle Communities').last);
      await tester.pumpAndSettle();
      expect(find.text('Demo Ateliertermin'), findsOneWidget);
      expect(api.bodies, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('event detail links to both community programs', (tester) async {
    final api = NavigationFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: ProgramDetailPage(
          api: api,
          kind: 'events',
          id: api.events.last['id'] as String,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final link = find.byKey(const ValueKey('community-link:$communityB'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Demo Atelier'), findsOneWidget);
    expect(api.eventQueries.last['community'], communityB);
    expect(find.text('Demo Abend'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'unknown listedCommunities never load an unscoped program and retry works',
    (tester) async {
      final api = NavigationFixture()..failNavigation = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityDetailPage(api: api, id: communityA),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.eventQueries, isEmpty);
      api.failNavigation = false;
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(api.eventQueries.single['community'], communityA);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityDetailPage(
            key: const ValueKey('unknown'),
            api: api,
            id: '30000000-0000-4000-8000-000000000009',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.eventQueries, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets(
      'community program search and date filters preserve assignment at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final language = AppLanguage()..value = true;
        addTearDown(language.dispose);
        final api = NavigationFixture();
        api.listedCommunities[0]['name'] =
            'Demo community for music, art and open cultural workshops';
        await tester.pumpWidget(
          LanguageScope(
            language: language,
            child: MaterialApp(
              theme: AccessDesign.theme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(width == 390 ? 2 : 1)),
                child: child!,
              ),
              home: CommunityDetailPage(api: api, id: communityA),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(AccessBrand)).width, 112);
        final field = find.byType(TextField);
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Gemeinsamer');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(api.eventQueries.last['q'], 'Gemeinsamer');
        expect(api.eventQueries.last['community'], communityA);
        final date = find.text('Tomorrow');
        await tester.ensureVisible(date);
        await tester.tap(date);
        await tester.pumpAndSettle();
        expect(api.eventQueries.last['from'], isNotNull);
        expect(api.eventQueries.last['community'], communityA);
        expect(api.bodies, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
