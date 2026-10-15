import 'field_finder.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/bookmark_views.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/organizer_management_page.dart';
import 'package:community_access_client/visibility_preview_page.dart';
import 'package:community_access_client/program_views.dart';

import 'directory_widget_test.dart';
import 'program_widget_test.dart';

const secondProfile = '00000000-0000-4000-8000-000000000004';

class FeatureFixture extends ProgramFixture {
  final saved = <String>{};
  bool hiddenBookmark = false;
  final profiles = <Map<String, dynamic>>[
    {
      'id': profileId,
      'name': 'Demo privates Profil',
      'description': 'Synthetische Vorstellung',
      'awareness_concept': true,
      'awareness_team': false,
      'is_public': false,
      'allow_application': false,
      'allow_form': false,
      'allow_link': false,
      'version': 1,
      'community_ids': ['community'],
      'form': [],
    },
    {
      'id': secondProfile,
      'name': 'Demo öffentliches Profil',
      'description': 'Synthetische Vorstellung',
      'awareness_concept': true,
      'awareness_team': false,
      'is_public': true,
      'allow_application': false,
      'allow_form': false,
      'allow_link': false,
      'version': 1,
      'community_ids': ['community'],
      'form': [],
    },
  ];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'manage') {
      calls.add('$path:${query ?? {}}');
      final p = profiles.firstWhere(
        (p) => p['id'] == (query?['profile_id'] ?? profileId),
      );
      return {
        'profile': p,
        'profiles': profiles,
        'communities': communities,
        'events': events,
        'series': [],
        'grants': [],
        'requests': [],
        'links': [],
      };
    }
    if (path == 'manage/profile') {
      bodies.add(body!);
      if (body['create'] == true) {
        profiles.add({
          ...body,
          'id': '00000000-0000-4000-8000-000000000005',
          'version': 1,
        });
        return {'id': profiles.last['id'], 'version': 1};
      }
      return {'id': body['id'], 'version': 2};
    }
    if (path == 'series/$seriesId') {
      return {...series.first, 'events': events, 'signed_in': true};
    }
    if (path == 'bookmarks') {
      return {
        'profiles': [
          if (saved.contains('profile:$profileId') && !hiddenBookmark)
            {'id': profileId, 'title': 'Demo gemerkt'},
        ],
        'series': [
          if (saved.contains('series:$seriesId') && !hiddenBookmark)
            {'id': seriesId, 'title': 'Demo Nebelreihe'},
        ],
      };
    }
    if (path == 'bookmark') {
      bodies.add(body!);
      final key = '${body['kind']}:${body['id']}';
      body['saved'] == true ? saved.add(key) : saved.remove(key);
      return {'saved': body['saved']};
    }
    if (path == 'manage/preview') {
      bodies.add(body!);
      final visible =
          body['audience'] == 'event' || body['audience'] == 'confirmed';
      return {
        'visible': visible,
        'title': visible ? 'Demo Vorschauabend' : null,
        'location': '',
        'starts_at': null,
        'series': '',
        'status': 'published',
        'access_details': visible
            ? {'step_free': 'yes', 'awareness_notes': 'Demo Team am Eingang'}
            : {},
      };
    }
    return super.directory(path, query: query, body: body);
  }
}

Future<void> render(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(theme: AccessDesign.theme(), home: page));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'profile selector scopes management; creating another profile preserves its explicit draft',
    (tester) async {
      final api = FeatureFixture();
      await render(tester, OrganizerManagementPage(api: api));
      final profileChoice = fieldWithLabel(
        DropdownButtonFormField<String>,
        'Veranstalterprofil auswählen',
      );
      await tester.ensureVisible(profileChoice);
      await tester.tap(profileChoice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo öffentliches Profil').last);
      await tester.pumpAndSettle();
      expect(api.calls.last, contains(secondProfile));
      expect(
        find.widgetWithText(TextField, 'Demo öffentliches Profil'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.text('Weiteres Veranstalterprofil anlegen'),
      );
      await tester.tap(find.text('Weiteres Veranstalterprofil anlegen'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Neues Profil: Erst speichern, dann Veranstaltungen anlegen.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Profilname'),
        'Demo drittes Profil',
      );
      await tester.ensureVisible(find.text('Demo Musik'));
      await tester.tap(find.text('Demo Musik'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Profilbeschreibung'),
        'Synthetische Vorstellung',
      );
      for (final label in [
        'Awarenesskonzept vorhanden?',
        'Awarenessteam vorhanden?',
      ]) {
        final field = fieldWithLabel(DropdownButtonFormField<bool>, label);
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nein').last);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Profil speichern'));
      await tester.tap(find.text('Profil speichern'));
      await tester.pumpAndSettle();
      expect(api.bodies.last['create'], true);
      expect(api.bodies.last.containsKey('id'), false);
      expect(api.bodies.last['is_public'], false);
      expect(api.profiles.length, 3);
      expect(api.calls.last, contains('00000000-0000-4000-8000-000000000005'));
    },
  );
  testWidgets(
    'bookmark controls persist explicit intent and list drops unavailable records on refresh',
    (tester) async {
      final api = FeatureFixture();
      await render(
        tester,
        Scaffold(
          body: BookmarkButton(api: api, kind: 'profile', id: profileId),
        ),
      );
      await tester.tap(find.text('Veranstalter merken'));
      await tester.pumpAndSettle();
      expect(api.bodies.last, {
        'kind': 'profile',
        'id': profileId,
        'saved': true,
      });
      expect(find.text('Aus Merkliste entfernen'), findsOneWidget);
      await render(tester, BookmarksPage(api: api));
      expect(find.text('Demo gemerkt'), findsOneWidget);
      api.hiddenBookmark = true;
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Demo gemerkt'), findsNothing);
      expect(
        find.text('Noch keine verfügbaren Einträge in deiner Merkliste.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'visible series detail connects series bookmarking without any participation action',
    (tester) async {
      final api = FeatureFixture()..allowed = true;
      await render(
        tester,
        ProgramDetailPage(api: api, kind: 'series', id: seriesId),
      );
      await tester.tap(find.text('Reihe merken'));
      await tester.pumpAndSettle();
      expect(api.bodies.last, {
        'kind': 'series',
        'id': seriesId,
        'saved': true,
      });
      expect(find.text('Aus Merkliste entfernen'), findsOneWidget);
      expect(find.text('Teilnahme anfragen'), findsNothing);
      await tester.tap(find.text('Aus Merkliste entfernen'));
      await tester.pumpAndSettle();
      expect(api.bodies.last['saved'], false);
    },
  );
  testWidgets(
    'preview distinguishes visibility, participation and separate address retrieval',
    (tester) async {
      final api = FeatureFixture();
      await render(tester, VisibilityPreviewPage(api: api, eventId: eventId));
      expect(find.text('Demo Vorschauabend'), findsNothing);
      expect(
        find.text('Dieses Event erscheint in dieser Ansicht nicht.'),
        findsOneWidget,
      );
      for (final label in [
        'Nur Profilzugang',
        'Einzelne Eventfreigabe',
        'Eventfreigabe und bestätigte Teilnahme',
      ]) {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(
          find.text('Demo Vorschauabend'),
          label == 'Nur Profilzugang' ? findsNothing : findsOneWidget,
        );
      }
      expect(api.bodies.last['audience'], 'confirmed');
      expect(find.text('Stufenloser Zugang: Ja'), findsOneWidget);
      expect(
        find.textContaining('Eine Teilnahmezusage wird separat geprüft.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Die geschützte genaue Adresse ist mit diesen Rechten derzeit nicht abrufbar.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'event editor saves specific accessibility and awareness details with unknown defaults',
    (tester) async {
      final api = FeatureFixture();
      await render(
        tester,
        EventDirectoryEditor(
          api: api,
          communities: api.communities,
          profileId: secondProfile,
          profilePublic: true,
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Eventtitel'),
        'Demo Zugänglichkeit',
      );
      await tester.ensureVisible(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Stufenloser Zugang',
        ),
      );
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Stufenloser Zugang',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ja').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'Awareness vor Ort'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Awareness vor Ort'),
        'Demo Team am Infopunkt',
      );
      await tester.ensureVisible(find.text('Eventangaben speichern'));
      await tester.tap(find.text('Eventangaben speichern'));
      await tester.pumpAndSettle();
      expect(api.bodies.last['profile_id'], secondProfile);
      expect(api.bodies.last['access_details']['step_free'], 'yes');
      expect(api.bodies.last['access_details']['accessible_toilet'], 'unknown');
      expect(
        api.bodies.last['access_details']['awareness_notes'],
        'Demo Team am Infopunkt',
      );
      expect(api.bodies.last['is_public'], false);
    },
  );
  for (final size in [const Size(320, 900), const Size(375, 900)]) {
    testWidgets('new features fit $size with doubled text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FeatureFixture();
      for (final page in [
        OrganizerManagementPage(api: api),
        BookmarksPage(api: api),
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: BookmarkButton(api: api, kind: 'profile', id: profileId),
          ),
        ),
        VisibilityPreviewPage(api: api, eventId: eventId),
        EventDirectoryEditor(
          api: api,
          communities: api.communities,
          profileId: secondProfile,
          profilePublic: true,
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: page.runtimeType.toString(),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
