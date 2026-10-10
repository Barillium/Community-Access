import 'dart:async';

import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/guest_preferences.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/social_login_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'social_auth_test.dart' show SocialFixtureApi;

class PreferencesFixture implements DirectoryApi {
  final String music;
  PreferencesFixture(this.music);
  Completer<Map<String, dynamic>>? pending;
  Object? failure;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (body != null && failure != null) throw failure!;
    if (body != null) return {};
    reads++;
    if (pending != null) return pending!.future;
    return {
      'preferences': {
        'music': [music],
      },
      'visited_organizers': [
        {'id': 'synthetic', 'name': 'Synthetic visit'},
      ],
    };
  }
}

class PendingSocial extends SocialFixtureApi {
  final destination = Completer<Uri>();
  @override
  Future<Uri> startSocial(String provider, {bool link = false}) =>
      destination.future;
}

void main() {
  testWidgets('system dialogs follow the selected app language', (
    tester,
  ) async {
    await tester.pumpWidget(
      CommunityAccessApp(api: SocialFixtureApi(), authOnly: true),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(GuestPage));
    final language = LanguageScope.of(context)!;
    expect(Localizations.localeOf(context).languageCode, 'de');
    expect(
      MaterialLocalizations.of(context).cancelButtonLabel.toLowerCase(),
      'abbrechen',
    );
    language.value = true;
    await tester.pumpAndSettle();
    expect(Localizations.localeOf(context).languageCode, 'en');
    expect(
      MaterialLocalizations.of(context).cancelButtonLabel.toLowerCase(),
      'cancel',
    );
    language.value = false;
    await tester.pumpAndSettle();
    expect(Localizations.localeOf(context).languageCode, 'de');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'preferences distinguish loading from retry and erase private values after denial',
    (tester) async {
      final api = PreferencesFixture('Synthetic music')
        ..pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(home: GuestPreferencesPage(api: api)),
      );
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsNothing);
      api.pending!.complete({
        'preferences': {
          'music': ['Synthetic music'],
        },
        'visited_organizers': [
          {'id': 'synthetic', 'name': 'Synthetic visit'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Synthetic music'), findsOneWidget);
      api.failure = const ApiFailure('Platform blocked', accessDenied: true);
      await tester.ensureVisible(find.text('Präferenzen speichern'));
      await tester.tap(find.text('Präferenzen speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic music'), findsNothing);
      expect(find.text('Synthetic visit'), findsNothing);
      expect(find.text('Platform blocked'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    },
  );

  testWidgets(
    'late preference response cannot replace another account values',
    (tester) async {
      final oldApi = PreferencesFixture('Old private music')
        ..pending = Completer<Map<String, dynamic>>();
      final newApi = PreferencesFixture('New synthetic music');
      await tester.pumpWidget(
        MaterialApp(home: GuestPreferencesPage(api: oldApi)),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(home: GuestPreferencesPage(api: newApi)),
      );
      await tester.pumpAndSettle();
      oldApi.pending!.complete({
        'preferences': {
          'music': ['Old private music'],
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('New synthetic music'), findsOneWidget);
      expect(find.text('Old private music'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unexpected attendance preference failure remains actionable without escaping',
    (tester) async {
      final api = PreferencesFixture('Synthetic music')
        ..failure = StateError('Synthetic connection failure');
      await tester.pumpWidget(
        MaterialApp(home: GuestPreferencesPage(api: api)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Besuchssignal löschen'));
      await tester.tap(find.text('Besuchssignal löschen'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Die Aktion konnte nicht abgeschlossen werden. Bitte prüfe den aktuellen Stand.',
        ),
        findsOneWidget,
      );
      expect(find.text('Synthetic visit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('provider response from replaced account cannot navigate', (
    tester,
  ) async {
    final oldApi = PendingSocial();
    var navigations = 0;
    Widget panel(SocialAuthApi api) => MaterialApp(
      home: Scaffold(
        body: SocialLoginPanel(
          api: api,
          navigate: (_) {
            navigations++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpWidget(panel(oldApi));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mit Google anmelden'));
    await tester.pump();
    await tester.pumpWidget(panel(SocialFixtureApi()..providers = ['apple']));
    await tester.pumpAndSettle();
    oldApi.destination.complete(
      Uri.parse('https://accounts.google.com/synthetic'),
    );
    await tester.pumpAndSettle();
    expect(navigations, 0);
    expect(find.text('Mit Apple anmelden'), findsOneWidget);
    expect(find.text('Mit Google anmelden'), findsNothing);
  });

  testWidgets(
    'successful social reauthentication returns to the resource route',
    (tester) async {
      final api = SocialFixtureApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GuestPage(
                      api: api,
                      authOnly: true,
                      initialSocialResult: 'success',
                      returnAfterLogin: true,
                      closeApiOnDispose: false,
                    ),
                  ),
                ),
                child: const Text('Synthetic resource'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Synthetic resource'));
      await tester.pumpAndSettle();
      expect(api.completed, 1);
      expect(find.byType(GuestPage), findsNothing);
      expect(find.text('Synthetic resource'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new shared navigation and failure hints have English copy', (
    tester,
  ) async {
    final language = AppLanguage()..value = true;
    await tester.pumpWidget(
      LanguageScope(
        language: language,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LocalText('Zurück zur Verwaltung'),
                LocalText('Beschwerde bereits eingereicht.'),
                LocalText('Gewählte Community'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Back to management'), findsOneWidget);
    expect(find.text('Complaint already submitted.'), findsOneWidget);
    expect(find.text('Selected community'), findsOneWidget);
    language.dispose();
  });
}
