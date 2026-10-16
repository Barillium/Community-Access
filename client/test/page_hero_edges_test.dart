import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/community_detail_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/flyer_design.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/product_scope.dart';

import 'community_navigation_test.dart' show NavigationFixture, communityA;
import 'directory_widget_test.dart' show DirectoryFixture, profileId;

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final route in [
      'Communities',
      'Veranstalter',
      if (ProductScope.extended) 'Orte',
      'community',
      'organizer',
      'venue',
    ]) {
      testWidgets('$route hero fills edges below header at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final index = !['community', 'organizer', 'venue'].contains(route);
        final api = DirectoryFixture();
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            home: switch (route) {
              'community' => CommunityDetailPage(
                api: NavigationFixture(),
                id: communityA,
              ),
              'organizer' => OrganizerDetailPage(api: api, id: profileId),
              'venue' => VenueDetailPage(api: api, name: 'Demo Kulturhalle'),
              _ => CommunityAccessApp(
                api: api,
                authOnly: true,
                showPublicHome: true,
              ),
            },
          ),
        );
        await tester.pumpAndSettle();
        if (index) {
          if (find.byTooltip('Menü').evaluate().isNotEmpty) {
            await tester.tap(find.byTooltip('Menü'));
            await tester.pumpAndSettle();
            final menuLink = find.descendant(
              of: find.byWidgetPredicate((w) => w is PopupMenuItem),
              matching: find.text(route),
            );
            await tester.ensureVisible(menuLink);
            await tester.tap(menuLink);
          } else {
            await tester.tap(find.text(route).first);
          }
          await tester.pumpAndSettle();
        }
        final hero = tester.getRect(find.byType(FlyerScene));
        final header = tester.getRect(
          find.byType(AccessHeader).evaluate().isEmpty
              ? find.byType(AppBar)
              : find.byType(AccessHeader),
        );
        expect(hero.left, 0);
        expect(hero.right, width);
        expect(hero.top, header.bottom);
        final body = switch (route) {
          'organizer' => find.text('Demo Beschreibung'),
          'venue' => find.text('Demo vergangener Abend'),
          _ => find.byType(TextField).first,
        };
        final bodyRect = tester.getRect(body);
        expect(bodyRect.left, greaterThan(0));
        expect(bodyRect.right, lessThan(width));
        expect(bodyRect.top, greaterThanOrEqualTo(hero.bottom));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('long English community hero grows with double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final language = AppLanguage()..value = true;
    addTearDown(language.dispose);
    final api = NavigationFixture();
    api.listedCommunities.first['name'] =
        'Shared workshops, performances and neighbourhood gatherings';
    await tester.pumpWidget(
      LanguageScope(
        language: language,
        child: MaterialApp(
          theme: AccessDesign.theme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CommunityDetailPage(api: api, id: communityA),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final hero = tester.getRect(find.byType(FlyerScene));
    expect(hero.left, 0);
    expect(hero.right, 320);
    expect(hero.top, tester.getRect(find.byType(AccessHeader)).bottom);
    expect(hero.height, greaterThan(320));
    expect(tester.takeException(), isNull);
  });
}
