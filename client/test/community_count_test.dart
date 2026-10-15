import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/app_language.dart';

import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/communities_page.dart';

import 'communities_widget_test.dart' show CommunityFixture;

Widget page(CommunityFixture api, {AppLanguage? language}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AccessDesign.theme(),
  home: LanguageScope(
    language: language ?? AppLanguage(),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CommunitiesPage(
          api: api,
          openAccount: () async {},
          onOrganizers: (_) {},
          onFaq: () {},
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Archivo',
    )..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'))).load();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'))).load();
    await (FontLoader(
      'packages/ca_design/CaIcons',
    )..addFont(rootBundle.load('packages/ca_design/fonts/CaIcons.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final english in [false, true]) {
        testWidgets(
          'community counts stay bottom right: $width / $scale / $english',
          (tester) async {
            tester.view.physicalSize = Size(width, 2600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final api = CommunityFixture();
            api.publicCommunities.clear();
            for (final n in [0, 1, 24]) {
              api.publicCommunities.add({
                'id': 'count-$n',
                'name': 'Demo Community $n',
                'event_count': n,
              });
            }
            await tester.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('count-board'),
                child: page(api, language: AppLanguage()..value = english),
              ),
            );
            await tester.pumpAndSettle();
            for (final n in [0, 1, 24]) {
              final card = tester.getRect(
                find.byKey(ValueKey('community-card:count-$n')),
              );
              final counter = find.byKey(ValueKey('community-count:count-$n'));
              expect(
                find.text(
                  '$n ${english ? (n == 1 ? 'event' : 'events') : (n == 1 ? 'Veranstaltung' : 'Veranstaltungen')}',
                ),
                findsOneWidget,
              );
              expect(tester.getRect(counter).right, closeTo(card.right, 1));
              expect(tester.getRect(counter).bottom, lessThan(card.bottom));
            }
            expect(tester.takeException(), isNull);
            expect(api.bodies, isEmpty);
            final output = Platform.environment['CA_COMMUNITY_BOARDS_DIR'];
            if (output != null &&
                scale == 1 &&
                !english &&
                [390.0, 1440.0].contains(width)) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('count-board')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File('$output/communities-${width.toInt()}.png')
                    .writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          },
        );
      }
    }
  }
  testWidgets('missing or invalid count is not presented as zero', (
    tester,
  ) async {
    for (final value in [null, -1, '4']) {
      final api = CommunityFixture();
      api.publicCommunities.first['event_count'] = value;
      await tester.pumpWidget(page(api));
      await tester.pumpAndSettle();
      expect(find.text('Anzahl nicht verfügbar'), findsOneWidget);
      expect(find.text('0 Veranstaltungen'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
