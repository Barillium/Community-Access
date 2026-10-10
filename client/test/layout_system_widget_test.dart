import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/account_registration_page.dart';
import 'package:community_access_client/bookmark_views.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/event_page.dart';
import 'package:community_access_client/invitation_page.dart';
import 'package:community_access_client/organizer_management_page.dart';
import 'package:community_access_client/program_management_page.dart';
import 'package:community_access_client/visibility_preview_page.dart';

import 'directory_widget_test.dart' show profileId;
import 'event_page_test.dart' show DetailApi;
import 'invitation_page_test.dart' show InvitationApi;
import 'mobile_tablet_widget_test.dart' show ResponsiveFixture;
import 'organizer_features_test.dart' show FeatureFixture;
import 'program_widget_test.dart' show eventId;

Future<void> render(
  WidgetTester tester,
  Widget page, {
  double width = 375,
  double scale = 1,
  AccessLayoutTheme layout = const AccessLayoutTheme(),
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AccessDesign.theme().copyWith(extensions: [layout]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('central gutter override changes registration and venue layouts', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final page in [
      () => AccountRegistrationPage(api: ResponsiveFixture()),
      () => VenueDetailPage(api: ResponsiveFixture(), name: 'Demo Kulturhalle'),
    ]) {
      await render(tester, page());
      final heading = find.byType(AccessHeading).first;
      final before = tester.getTopLeft(heading).dx;
      // Dispose the previous page so its fixture/state is not carried forward.
      await tester.pumpWidget(const SizedBox.shrink());
      await render(
        tester,
        page(),
        layout: const AccessLayoutTheme(gutterMin: 24, gutterMax: 32),
      );
      expect(
        tester.getTopLeft(find.byType(AccessHeading).first).dx - before,
        closeTo(8, 0.01),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  for (final boundary in [720.0, 900.0, 1000.0]) {
    for (final offset in [-1.0, 0.0, 1.0]) {
      testWidgets(
        'columns at ${boundary + offset} preserve content and order',
        (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const first = Key('first'), second = Key('second');
          await render(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                child: AccessColumns(
                  minWidth: boundary,
                  children: const [
                    Text('Demo erster Bereich', key: first),
                    Text('Demo zweiter Bereich', key: second),
                  ],
                ),
              ),
            ),
            width: boundary + offset,
          );
          final a = tester.getTopLeft(find.byKey(first));
          final b = tester.getTopLeft(find.byKey(second));
          if (offset < 0) {
            expect(b.dy, greaterThan(a.dy));
            expect(b.dx, a.dx);
          } else {
            expect(b.dy, a.dy);
            expect(b.dx, greaterThan(a.dx));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'large text stacks otherwise wide columns without shrinking text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.29, 1.3, 2.0]) {
        await render(
          tester,
          const Scaffold(
            body: AccessColumns(
              children: [
                Text('Demo A', key: Key('a')),
                Text('Demo B', key: Key('b')),
              ],
            ),
          ),
          width: 1440,
          scale: scale,
        );
        final a = tester.getTopLeft(find.byKey(const Key('a')));
        final b = tester.getTopLeft(find.byKey(const Key('b')));
        expect(b.dy > a.dy, scale >= 1.3);
        final context = tester.element(find.byKey(const Key('a')));
        expect(MediaQuery.textScalerOf(context).scale(16), 16 * scale);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final width in [320.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('internal pages and editors fit $width at $scale text', (
        tester,
      ) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pages = <Widget Function()>[
          () => OrganizerManagementPage(api: FeatureFixture()),
          () => ProgramManagementPage(
            api: FeatureFixture(),
            profileId: profileId,
          ),
          () => BookmarksPage(api: FeatureFixture()),
          () => VisibilityPreviewPage(api: FeatureFixture(), eventId: eventId),
          () => SeriesEditor(
            api: FeatureFixture(),
            communities: const [
              {'id': 'community', 'name': 'Demo Community mit langem Namen'},
            ],
          ),
          () => EventDirectoryEditor(
            api: FeatureFixture(),
            communities: const [
              {'id': 'community', 'name': 'Demo Community mit langem Namen'},
            ],
          ),
          () => InvitationPage(api: InvitationApi(), authenticated: false),
          () => EventPage(api: DetailApi(), eventId: 1),
        ];
        for (final make in pages) {
          final page = make();
          await render(tester, page, width: width, scale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: page.runtimeType.toString(),
          );
          expect(find.byType(AccessPageFrame), findsWidgets);
          final frame = tester.getRect(find.byType(AccessPageFrame).first);
          expect(frame.right, lessThanOrEqualTo(width));
          expect(frame.left, greaterThanOrEqualTo(0));
          final scroll = find.byType(Scrollable).first;
          final position = tester.state<ScrollableState>(scroll).position;
          position.jumpTo(position.maxScrollExtent);
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
}
