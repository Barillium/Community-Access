import 'package:community_access_client/directory_pages.dart';

import 'directory_widget_test.dart' show DirectoryFixture;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:community_access_client/program_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/organizer_management_page.dart';

import 'layout_system_widget_test.dart' show render;
import 'auth_account_widget_test.dart' show AuthAccountApi;
import 'organizer_features_test.dart' show FeatureFixture;

void noClippedText(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: paragraph.text.toPlainText(),
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('directory filter options remain readable with doubled text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: DirectoryBrowser(
            api: DirectoryFixture(),
            venues: false,
            openAccount: () async {},
          ),
        ),
      ),
      width: 320,
      scale: 2,
    );
    noClippedText(tester);
  });
  setUpAll(() async {
    final loader = FontLoader('Rubik');
    loader.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Rubik-Regular.ttf').readAsBytesSync(),
        ),
      ),
    );
    await loader.load();
  });
  testWidgets(
    'series and accessibility field captions fit with the real font',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(
        tester,
        SeriesEditor(api: FeatureFixture(), communities: const []),
        width: 320,
        scale: 2,
      );
      noClippedText(tester);
      await render(
        tester,
        EventDirectoryEditor(api: FeatureFixture(), communities: const []),
        width: 768,
        scale: 2,
      );
      noClippedText(tester);
    },
  );
  testWidgets(
    'long input captions and hints remain complete and labelled at double text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      const label =
          'Vollständige synthetische Beschriftung für die Formularprüfung';
      const hint =
          'Ein längerer synthetischer Hinweis, dessen Inhalt vollständig lesbar bleiben muss.';
      String? changed;
      await render(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: AccessPageFrame(
              child: AccessField(
                decoration: const InputDecoration(
                  labelText: label,
                  hintText: hint,
                ),
                builder: (decoration) => TextField(
                  decoration: decoration,
                  onChanged: (value) => changed = value,
                ),
              ),
            ),
          ),
        ),
        width: 320,
        scale: 2,
      );
      expect(find.text(label), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TextField)).label,
        contains(label),
      );
      await tester.enterText(find.byType(TextField), 'synthetisch');
      expect(changed, 'synthetisch');
      noClippedText(tester);
      semantics.dispose();
    },
  );
  testWidgets('selected dropdown and open options wrap instead of clipping', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const name =
        'Demo Veranstalterprofil mit einem sehr langen synthetischen Namen';
    String? changed;
    await render(
      tester,
      Scaffold(
        body: AccessPageFrame(
          child: AccessField(
            decoration: const InputDecoration(
              labelText: 'Veranstalterprofil auswählen',
            ),
            builder: (decoration) => DropdownButtonFormField<String>(
              decoration: decoration,
              initialValue: 'one',
              isExpanded: true,
              itemHeight: null,
              items: const [
                DropdownMenuItem(value: 'one', child: AccessOptionText(name)),
                DropdownMenuItem(
                  value: 'two',
                  child: AccessOptionText('Demo zweites Profil'),
                ),
              ],
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      ),
      width: 320,
      scale: 2,
    );
    noClippedText(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    noClippedText(tester);
    await tester.tap(find.text('Demo zweites Profil').last);
    await tester.pumpAndSettle();
    expect(changed, 'two');
  });
  testWidgets('long toolbar title grows and remains visible at double text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title =
        'Synthetische Veranstaltungsorte mit einem langen Seitentitel';
    await render(
      tester,
      Builder(
        builder: (context) => Scaffold(
          appBar: accessAppBar(context, title),
          body: const Text('Inhalt'),
        ),
      ),
      width: 320,
      scale: 2,
    );
    noClippedText(tester);
    expect(
      tester.getRect(find.text(title)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
    );
  });
  testWidgets('login title size stays continuous when its columns change', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sizes = <double>[];
    for (final width in [1047.0, 1048.0]) {
      await render(
        tester,
        GuestPage(api: AuthAccountApi(), authOnly: true),
        width: width,
      );
      sizes.add(
        tester
            .widget<Text>(find.text('Teil einer Community werden.'))
            .style!
            .fontSize!,
      );
      noClippedText(tester);
    }
    expect((sizes.last - sizes.first).abs(), lessThan(1));
    expect(sizes.last, greaterThan(50));
  });
  testWidgets(
    'login actions have a shared gap and account form keeps its width',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(
        tester,
        GuestPage(api: AuthAccountApi(), authOnly: true),
        width: 1440,
      );
      final login = tester.getRect(
        find.widgetWithText(FilledButton, 'Anmelden'),
      );
      final recovery = tester.getRect(
        find.widgetWithText(TextButton, 'Passwort vergessen?'),
      );
      final register = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Testkonto anlegen'),
      );
      expect(
        register.top -
            (login.bottom > recovery.bottom ? login.bottom : recovery.bottom),
        closeTo(AccessSpacing.s12, .01),
      );
      expect(
        tester.getSize(find.byType(AccessSurface).first).width,
        lessThanOrEqualTo(AccessLayout.formWidth),
      );
    },
  );
  testWidgets('host fields share the central form width on large screens', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      OrganizerManagementPage(api: FeatureFixture()),
      width: 1440,
    );
    for (final element in find.byType(AccessField).evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).width,
        lessThanOrEqualTo(AccessLayout.formWidth),
      );
    }
    noClippedText(tester);
  });
}
