import 'field_finder.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/account_registration_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/public_home_page.dart';

import 'directory_widget_test.dart' show DirectoryFixture;

class ResponsiveFixture extends DirectoryFixture {
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'communities') {
      return {
        'signed_in': false,
        'items': [
          {
            'id': 'community',
            'name': 'Demo Gemeinschaft für elektronische Klanglandschaften und gemeinsame Kultur',
            'following': false,
          },
        ],
      };
    }
    if (path == 'events') {
      return {
        'series': [],
        'events': [
          {
            'id': 'demo',
            'title': 'Demo Nacht der elektronischen Klanglandschaften',
            'status': 'published',
            'starts_at': null,
            'location': 'Demo Kulturhalle mit einem langen Ortsnamen',
          },
        ],
        'has_more': false,
      };
    }
    return super.directory(path, query: query, body: body);
  }
}

void main() {
  testWidgets(
    'registration stays scrollable above the keyboard at 320 pixels',
    (tester) async {
      tester.view.physicalSize = const Size(320, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 320),
            ),
            child: child!,
          ),
          home: AccountRegistrationPage(api: ResponsiveFixture()),
        ),
      );
      await tester.pumpAndSettle();
      final field = fieldWithLabel(TextFormField, 'Passwort bestätigen');
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'synthetisch-123');
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(812 - 320));
      expect(tester.takeException(), isNull);
      final submit = find.widgetWithText(AccessAction, 'Testkonto anlegen');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Trage einen erfundenen Namen ein.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 812),
    const Size(375, 812),
    const Size(414, 896),
    const Size(768, 1024),
    const Size(820, 1180),
    const Size(1024, 768),
    const Size(1440, 1000),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('discovery, navigation and forms fit $size at $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = ResponsiveFixture();
        api.communities.single['name'] =
            'Demo Community mit einem besonders langen Namen';
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: PublicHomePage(
              directoryApi: api,
              accountBuilder: (_) => GuestPage(api: api, authOnly: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final header = find.byType(AccessHeader);
        final headerTop = tester.getTopLeft(header).dy;
        final brand = find
            .descendant(of: header, matching: find.byType(TextButton))
            .first;
        final menu = find.byTooltip('Menü');
        if (menu.evaluate().isNotEmpty) {
          expect(
            tester.getCenter(menu).dy,
            closeTo(tester.getCenter(brand).dy, 1),
          );
          expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
          expect(tester.getRect(menu).right, lessThanOrEqualTo(size.width));
        } else {
          final account = find.text('Mein Zugang');
          expect(
            tester.getCenter(account).dy,
            closeTo(tester.getCenter(brand).dy, 6),
          );
        }
        if (size.width < 768 && scale == 1) {
          // Keep the main purpose visible without scrolling past all nav links.
          expect(
            tester.getTopLeft(find.text('Events & Communities.')).dy,
            lessThan(300),
          );
        }
        final search = fieldWithLabel(TextField, 'Event suchen');
        await tester.ensureVisible(search);
        final rect = tester.getRect(search);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));

        for (final name in [
          'Communities',
          'Veranstalter',
          'Orte',
          'FAQ',
          'Programm',
        ]) {
          final menu = find.byTooltip('Menü');
          final compactNavigation = menu.evaluate().isNotEmpty;
          if (compactNavigation) {
            await tester.ensureVisible(menu);
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
          }
          final link = compactNavigation
              ? find.descendant(
                  of: find.byWidgetPredicate(
                    (widget) => widget is PopupMenuItem,
                  ),
                  matching: find.text(name),
                )
              : find.descendant(
                  of: header,
                  matching: find.text(switch (name) {
                    'Events' => 'Programm',
                    'Veranstaltungsorte' => 'Orte',
                    _ => name,
                  }),
                );
          await tester.ensureVisible(link);
          await tester.tap(link);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$name at $size/$scale',
          );
          if (name == 'Communities') {
            expect(find.text('Öffentliche Communities'), findsOneWidget);
            expect(find.textContaining('Namensidee'), findsNothing);
            expect(
              find.text('Clubkultur & elektronische Musik'),
              findsOneWidget,
            );
            final lastTopic = find.text('Reisen & regionale Entdeckung');
            await tester.ensureVisible(lastTopic);
            await tester.pumpAndSettle();
            expect(
              tester.getTopLeft(header).dy,
              headerTop,
              reason: 'Header stays fixed at $size/$scale',
            );
            expect(tester.getRect(lastTopic).left, greaterThanOrEqualTo(0));
            expect(
              tester.getRect(lastTopic).right,
              lessThanOrEqualTo(size.width),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'Community catalogue at $size/$scale',
            );
          }
          if (name == 'FAQ') {
            final question = find.text('Was ist Community Access?');
            await tester.ensureVisible(question);
            await tester.tap(question);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Expanded FAQ at $size/$scale',
            );
            expect(
              find.textContaining(
                'Community Access hilft bestehenden Kollektiven',
              ),
              findsOneWidget,
            );
          }
          if (compactNavigation) {
            expect(
              find.byWidgetPredicate((widget) => widget is PopupMenuItem),
              findsNothing,
            );
          }
        }
        final compactMenu = find.byTooltip('Menü');
        if (compactMenu.evaluate().isNotEmpty) {
          await tester.tap(compactMenu);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Konto und Darstellung'));
          await tester.tap(find.text('Konto und Darstellung'));
          await tester.pumpAndSettle();
          expect(find.text('Darstellung'), findsOneWidget);
          expect(find.text('Sprache'), findsOneWidget);
          final login = find.text('Anmelden').first;
          await tester.ensureVisible(login);
          await tester.tap(login);
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('Mein Zugang'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final register = find.text('Testkonto anlegen');
        await tester.ensureVisible(register);
        await tester.tap(register);
        await tester.pumpAndSettle();
        expect(find.byType(AccountRegistrationPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        final submit = find.widgetWithText(AccessAction, 'Testkonto anlegen');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Trage einen erfundenen Namen ein.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
