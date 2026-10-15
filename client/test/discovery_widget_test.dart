import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/event_form_editor.dart';
import 'package:community_access_client/account_registration_page.dart';
import 'package:community_access_client/design_system.dart';

import 'auth_account_widget_test.dart';
import 'field_finder.dart';

import 'package:community_access_client/event_carousel.dart';

class DiscoveryFixture extends AuthAccountApi implements DirectoryApi {
  bool signed = false, failPreferences = false;
  final writes = <Map<String, dynamic>>[];
  final events = <Map<String, dynamic>>[
    {
      'id': 'one',
      'title': 'Demo Ambientabend',
      'status': 'published',
      'starts_at': '2026-11-01T20:00:00Z',
      'location': 'Demo Kulturhalle',
      'community': 'Demo Musik',
      'organizer': 'Demo Veranstalter',
      'event_content': {
        'description': 'Synthetischer Musikabend.',
        'genres': ['Ambient'],
      },
      'reasons': ['preferences'],
    },
    {
      'id': 'two',
      'title': 'Demo Secret Night',
      'status': 'published',
      'starts_at': null,
      'location': '',
      'community': 'Demo Musik',
      'organizer': 'Demo Veranstalter',
      'access_mode': 'semi_public',
      'event_content': {
        'description': 'Synthetische öffentlich beworbene Veranstaltung.',
        'genres': ['Techno'],
      },
      'reasons': ['community'],
    },
  ];
  @override
  Future<void> login(String email, String password) async {
    signed = true;
  }

  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (body != null) writes.add({'path': path, ...body});
    if (path == 'preferences' && failPreferences) {
      throw const ApiFailure('Präferenzen konnten nicht gespeichert werden.');
    }
    if (path == 'home') {
      return {
        'signed_in': signed,
        'hero': events,
        'events': events,
        'communities': [
          {'id': 'community', 'name': 'Demo Musik', 'following': false},
        ],
      };
    }
    if (path == 'events') return {'events': events, 'series': []};
    return {};
  }
}

void main() {
  testWidgets(
    'carousel advances title and right-hand details together and language switches the header',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        CommunityAccessApp(
          api: DiscoveryFixture(),
          authOnly: true,
          showPublicHome: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Ambientabend'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Kulturhalle'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Nächste Veranstaltung'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Ambientabend'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Kulturhalle'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Secret Night'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Secret Night'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Sprache auswählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('My access'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AccessHeader),
          matching: find.text('Organizers'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Previous event'), findsOneWidget);
      expect(find.text('Program'), findsWidgets);
      await tester.ensureVisible(find.byTooltip('Previous event'));
      await tester.tap(find.byTooltip('Previous event'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Ambientabend'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 900),
    const Size(768, 1024),
    const Size(1440, 1000),
  ]) {
    testWidgets('real carousel and communities fit $size with doubled text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CommunityAccessApp(
            api: DiscoveryFixture(),
            authOnly: true,
            showPublicHome: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Nächste Veranstaltung'));
      await tester.tap(find.byTooltip('Nächste Veranstaltung'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Secret Night'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'return from account reloads curated home and retains the shared hero',
    (tester) async {
      final api = DiscoveryFixture();
      await tester.pumpWidget(
        CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menü'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mein Zugang'));
      await tester.pumpAndSettle();
      api.signed = true;
      await tester.tap(find.text('Zur Hauptseite'));
      await tester.pumpAndSettle();
      expect(find.text('Für dich'), findsOneWidget);
      await tester.tap(find.byTooltip('Menü'));
      await tester.pumpAndSettle();
      expect(find.text('Mein Zugang'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(EventCarousel),
          matching: find.text('Demo Ambientabend'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('form cannot confirm an unreviewed privacy question', (
    tester,
  ) async {
    final api = DiscoveryFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: EventFormEditor(api: api, profileId: 'profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      fieldWithLabel(TextField, 'Formulartitel'),
      'Demo Gästefragen',
    );
    await tester.enterText(
      fieldWithLabel(TextField, 'Formularfrage'),
      'Welche Religion hast du?',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Formular speichern'),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('nicht geprüft'), findsWidgets);
    expect(api.writes, isEmpty);
    await tester.enterText(
      fieldWithLabel(TextField, 'Formularfrage'),
      safeQuestions.first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Formular speichern'));
    await tester.tap(find.text('Formular speichern'));
    await tester.pumpAndSettle();
    expect(api.writes.single['path'], 'manage/form');
  });
  testWidgets('registration stays minimal and defers optional preferences', (
    tester,
  ) async {
    final api = DiscoveryFixture()..failPreferences = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: AccountRegistrationPage(api: api),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (final entry in [
      'Demo Gast',
      'demo@example.invalid',
      'Synthetic-2026!',
      'Synthetic-2026!',
    ].asMap().entries) {
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    expect(find.text('Veranstaltungspräferenzen'), findsNothing);
    expect(find.text('Musikgeschmack'), findsNothing);
    await tester.ensureVisible(find.text('Testkonto anlegen'));
    await tester.tap(find.text('Testkonto anlegen'));
    await tester.pumpAndSettle();
    expect(api.registrations, 1);
    expect(
      api.writes.where((entry) => entry['path'] == 'preferences'),
      isEmpty,
    );
    expect(
      find.textContaining(
        'Bestätige deine E-Mail-Adresse und melde dich danach an.',
      ),
      findsOneWidget,
    );
  });
}
