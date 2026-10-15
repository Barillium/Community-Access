import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/legal_api.dart';
import 'package:community_access_client/legal_pages.dart';
import 'package:community_access_client/ticketing_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class LegalFixture implements LegalApi, TicketingApi {
  final writes = <Map<String, dynamic>>[];
  bool missingSeller = false;
  String termsVersion = legalDeclarationVersion;
  @override
  Future<Map<String, dynamic>> legal(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (body != null) writes.add({'path': path, ...body});
    if (body == null && path.startsWith('reports/')) {
      return {
        'id': 'synthetic-report',
        'event_id': 'synthetic-event',
        'event': {
          'id': 'synthetic-event',
          'title': 'Synthetic event',
          'legal_version': 4,
          'legal_state': 'active',
        },
        'version': 2,
        'reference': 'events/synthetic-event',
        'details': 'Synthetic concern',
        'actions': [],
        'statements': [],
      };
    }
    return {'received': true, 'reference': 'synthetic-receipt'};
  }

  @override
  Future<Map<String, dynamic>> ticketing(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (body != null) writes.add({'path': path, ...body});
    return {
      'seller': missingSeller
          ? null
          : {
              'legal_name': 'Synthetic seller',
              'address': 'Synthetic business address',
              'contact': 'seller@example.invalid',
              'seller_status': 'business',
            },
      'declaration': {'confirmed': true, 'version': 3},
      'ready': true,
      'terms_version': termsVersion,
      'event_version': 7,
      'seller_version': 2,
      'legal_state': 'active',
    };
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    bool english = false,
  }) async {
    final language = AppLanguage()..value = english;
    await tester.pumpWidget(
      LanguageScope(
        language: language,
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'anonymous report requires explicit good faith and valid contact before submission',
    (tester) async {
      final api = LegalFixture();
      await pump(tester, LegalReportPage(api: api, eventId: 'synthetic-event'));
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).last)
            .value,
        false,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tap(tester, find.byType(CheckboxListTile).last);
      await tap(tester, find.byType(FilledButton));
      expect(api.writes, isEmpty);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'Synthetic concrete permit concern');
      await tester.enterText(fields.at(2), 'Synthetic reporter');
      await tester.enterText(fields.at(3), 'reporter@example.invalid');
      await tap(tester, find.byType(FilledButton));
      expect(api.writes.single['good_faith'], true);
      expect(api.writes.single['event_id'], 'synthetic-event');
      expect(find.textContaining('synthetic-receipt'), findsOneWidget);
    },
  );
  testWidgets(
    'child safety exception accepts absent contact but still requires reference and good faith',
    (tester) async {
      final api = LegalFixture();
      await pump(tester, LegalReportPage(api: api));
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'events/synthetic-reference',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Synthetic child-safety concern',
      );
      await tap(tester, find.byType(CheckboxListTile).first);
      await tap(tester, find.byType(CheckboxListTile).last);
      await tap(tester, find.byType(FilledButton));
      expect(api.writes.single['contact_exception'], true);
      expect(api.writes.single['email'], '');
    },
  );
  testWidgets(
    'existing declaration never preselects consent and writes current versions',
    (tester) async {
      final api = LegalFixture();
      await pump(
        tester,
        EventDeclarationPage(api: api, eventId: 'synthetic-event'),
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tap(tester, find.byType(CheckboxListTile));
      await tap(tester, find.byType(FilledButton));
      expect(api.writes.single, {
        'path': 'events/synthetic-event/declaration',
        'confirmed': true,
        'version': 3,
        'event_version': 7,
        'seller_version': 2,
        'terms_version': 'local-responsibility-draft-20261009',
      });
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
    },
  );
  testWidgets(
    'a newer server text cannot be acknowledged with an older displayed declaration',
    (tester) async {
      final api = LegalFixture()..termsVersion = 'synthetic-future-text';
      await pump(
        tester,
        EventDeclarationPage(api: api, eventId: 'synthetic-event'),
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        find.text(
          'Der Erklärungstext wurde geändert. Bitte aktualisiere die Anwendung.',
        ),
        findsOneWidget,
      );
      expect(api.writes, isEmpty);
    },
  );
  testWidgets(
    'missing seller permits withholding responsibility but prevents confirmation',
    (tester) async {
      final api = LegalFixture()..missingSeller = true;
      await pump(
        tester,
        EventDeclarationPage(api: api, eventId: 'synthetic-event'),
      );
      await tap(tester, find.byType(CheckboxListTile));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tap(tester, find.byType(OutlinedButton));
      expect(api.writes.single['confirmed'], false);
    },
  );
  testWidgets(
    'review decision submits observed event version without silently fetching a newer state',
    (tester) async {
      final api = LegalFixture();
      await pump(
        tester,
        LegalReviewDetailPage(
          api: api,
          item: const {'id': 'synthetic-report'},
          team: true,
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Synthetic documented clarification',
      );
      await tap(tester, find.byType(FilledButton));
      expect(api.writes.single['event_legal_version'], 4);
      expect(api.writes.single['action'], 'sales_paused');
    },
  );
  for (final english in [false, true]) {
    testWidgets(
      'legal forms fit narrow mobile screen in language english=$english',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = LegalFixture();
        for (final page in [
          LegalReportPage(api: api),
          EventDeclarationPage(api: api, eventId: 'synthetic-event'),
          SellerManagementPage(api: api, profileId: 'synthetic-profile'),
          LegalReviewDetailPage(
            api: api,
            item: const {'id': 'synthetic-report'},
            team: true,
          ),
        ]) {
          await pump(tester, page, english: english);
          expect(tester.takeException(), isNull);
        }
        await pump(tester, LegalReportPage(api: api), english: english);
        expect(
          find.widgetWithText(
            AccessHeading,
            english ? 'Report event' : 'Veranstaltung melden',
          ),
          findsOneWidget,
        );
      },
    );
  }
}
