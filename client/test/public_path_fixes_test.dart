import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/bookmark_views.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/public_home_page.dart';

import 'directory_widget_test.dart' show DirectoryFixture, profileId;
import 'program_widget_test.dart' show ProgramFixture, eventId;

class BookmarkFixture implements DirectoryApi {
  final reads = <Completer<Map<String, dynamic>>>[];
  bool expired = false;
  bool deferred = false;
  bool saved = true;
  bool uncertainWrite = false;
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (expired) {
      throw const ApiFailure('Sitzung abgelaufen.', unauthenticated: true);
    }
    if (path == 'bookmarks') {
      if (deferred) {
        final read = Completer<Map<String, dynamic>>();
        reads.add(read);
        return read.future;
      }
      return {
        'profiles': [],
        'series': [],
        'events': [
          if (saved) {'id': eventId, 'title': 'Demo Merkeintrag'},
        ],
      };
    }
    if (path == 'bookmark') {
      saved = body!['saved'] == true;
      if (uncertainWrite) throw StateError('Synthetic response lost');
      return {'saved': saved};
    }
    throw const ApiFailure('Dieser Eintrag ist nicht verfügbar.');
  }
}

Widget frame(Widget child) => MaterialApp(
  theme: AccessDesign.theme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'a late bookmark read cannot restore the previous account state',
    (tester) async {
      final api = BookmarkFixture()..deferred = true;
      Widget render(bool signedIn) => frame(
        BookmarkButton(
          api: api,
          kind: 'event',
          id: eventId,
          signedIn: signedIn,
        ),
      );
      await tester.pumpWidget(render(true));
      await tester.pump();
      await tester.pumpWidget(render(false));
      await tester.pumpWidget(render(true));
      await tester.pump();
      expect(api.reads, hasLength(2));
      api.reads.last.complete({'events': []});
      await tester.pumpAndSettle();
      api.reads.first.complete({
        'events': [
          {'id': eventId},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Event merken'), findsOneWidget);
      expect(find.text('Aus Merkliste entfernen'), findsNothing);
    },
  );

  testWidgets(
    'an uncertain bookmark write requires a fresh read before retry',
    (tester) async {
      final api = BookmarkFixture()..uncertainWrite = true;
      await tester.pumpWidget(
        frame(BookmarkButton(api: api, kind: 'event', id: eventId)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aus Merkliste entfernen'));
      await tester.pumpAndSettle();
      expect(api.saved, false); // Write succeeded, only its response was lost.
      expect(find.text('Aus Merkliste entfernen'), findsNothing);
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Event merken'), findsOneWidget);
    },
  );

  testWidgets('expired bookmarks offer sign-in and reload the same list', (
    tester,
  ) async {
    final api = BookmarkFixture()..expired = true;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: BookmarksPage(
          api: api,
          openAccount: () async {
            opened++;
            api.expired = false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Demo Merkeintrag'), findsNothing);
    await tester.tap(find.text('Erneut anmelden'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Demo Merkeintrag'), findsOneWidget);
  });

  testWidgets('a bookmarked resource retains a real sign-in return path', (
    tester,
  ) async {
    final api = BookmarkFixture();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: BookmarksPage(
          api: api,
          openAccount: () async {
            opened++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ansehen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anmelden und Zugriff erneut prüfen'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byType(ProgramDetailPage), findsOneWidget);
  });

  testWidgets(
    'an explicit organizer link takes priority over an older saved event',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: PublicHomePage(
            accountBuilder: (_) => const Scaffold(body: Text('Konto')),
            directoryApi: DirectoryFixture(),
            initialOrganizer: profileId,
            initialResource: const {'kind': 'event', 'id': eventId},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrganizerDetailPage), findsOneWidget);
      expect(find.byType(ProgramDetailPage), findsNothing);
      expect(find.text('Demo Kollektiv'), findsOneWidget);
    },
  );

  testWidgets('a filtered directory stays usable after a failed reload', (
    tester,
  ) async {
    final api = DirectoryFixture();
    await tester.pumpWidget(
      frame(
        SingleChildScrollView(
          child: DirectoryBrowser(
            api: api,
            venues: false,
            openAccount: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle Communities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Musik').last);
    await tester.pumpAndSettle();
    api.directoryFails = true;
    await tester.tap(find.text('Suchen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Testfehler: Bitte erneut laden.'), findsOneWidget);
    expect(find.text('Gewählte Community'), findsOneWidget);
    api.directoryFails = false;
    await tester.tap(find.text('Erneut laden'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Kollektiv'), findsOneWidget);
  });

  testWidgets('returning from an organizer rechecks access to the event', (
    tester,
  ) async {
    final api = NestedProfileFixture()..allowed = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: ProgramDetailPage(
          api: api,
          kind: 'events',
          id: eventId,
          openAccount: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Demo Kollektiv'));
    await tester.tap(find.text('Demo Kollektiv'));
    await tester.pumpAndSettle();
    expect(find.byType(OrganizerDetailPage), findsOneWidget);
    api.allowed = false;
    Navigator.of(tester.element(find.byType(OrganizerDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Demo Nebelabend'), findsNothing);
    expect(find.text('Dieser Eintrag ist nicht verfügbar.'), findsOneWidget);
  });

  testWidgets(
    'revoked profile access discards the previous application answers',
    (tester) async {
      final api = RevokedProfileFixture()
        ..private = true
        ..signedIn = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: OrganizerDetailPage(
            api: api,
            id: profileId,
            openAccount: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Synthetischer Entwurf');
      api.revoked = true;
      await tester.ensureVisible(find.text('Aktualisieren'));
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      api.revoked = false;
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('follow serializes rapid clicks and reconciles a lost response', (
    tester,
  ) async {
    final api = FollowFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: PublicHomePage(
          directoryApi: api,
          accountBuilder: (_) => const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Communities'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Folgen'));
    await tester.tap(find.text('Folgen'));
    await tester.tap(find.text('Folgen'));
    expect(api.writes, 1);
    api.response.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nicht mehr folgen'), findsOneWidget);
    expect(
      find.text(
        'Folgen konnte nicht gespeichert werden. Bitte prüfe den aktuellen Status.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'interest counters and bookmark errors follow the selected language',
    (tester) async {
      final language = AppLanguage()..value = true;
      addTearDown(language.dispose);
      final api = BookmarkFixture()..expired = true;
      await tester.pumpWidget(
        LanguageScope(
          language: language,
          child: frame(
            Column(
              children: [
                const InterestCount(count: 1),
                const InterestCount(count: 12),
                BookmarkButton(
                  api: api,
                  kind: 'event',
                  id: eventId,
                  openAccount: () async {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 person interested'), findsOneWidget);
      expect(find.text('12 people interested'), findsOneWidget);
      expect(find.text('Sign in and save'), findsOneWidget);
    },
  );

  testWidgets('venue listings open the actual event detail', (tester) async {
    final api = VenueFixture()..allowed = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: VenueDetailPage(api: api, name: 'Demo Ort'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Event ansehen'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramDetailPage), findsOneWidget);
    expect(find.text('Demo Nebelabend'), findsOneWidget);
  });
}

class VenueFixture extends ProgramFixture {
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'venue') {
      return {
        'events': [
          {...events.first, 'community': 'Demo Musik'},
        ],
      };
    }
    return super.directory(path, query: query, body: body);
  }
}

class NestedProfileFixture extends ProgramFixture {
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final data = await super.directory(path, query: query, body: body);
    return path == 'events/$eventId'
        ? {...data, 'organizer': 'Demo Kollektiv', 'organizer_id': profileId}
        : data;
  }
}

class RevokedProfileFixture extends DirectoryFixture {
  bool revoked = false;
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (revoked) {
      throw const ApiFailure('Zugriff entzogen.', accessDenied: true);
    }
    return super.directory(path, query: query, body: body);
  }
}

class FollowFixture implements DirectoryApi {
  int writes = 0;
  bool following = false;
  final response = Completer<void>();
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'home') {
      return {
        'signed_in': true,
        'hero': [],
        'events': [],
        'communities': [
          {'id': 'community', 'name': 'Demo Community', 'following': following},
        ],
      };
    }
    if (path == 'events') {
      return {'events': [], 'series': [], 'has_more': false};
    }
    if (path == 'follow') {
      writes++;
      await response.future;
      following = true;
      throw StateError('Synthetic response lost');
    }
    throw const ApiFailure('Nicht verfügbar.');
  }
}
