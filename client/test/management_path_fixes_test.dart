import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/access_flow_api.dart';
import 'package:community_access_client/access_flow_page.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/organizer_management_page.dart';
import 'package:community_access_client/private_access_management_page.dart';
import 'package:community_access_client/program_management_page.dart';

import 'access_flow_test.dart' show FlowApi;
import 'directory_widget_test.dart' show DirectoryFixture, profileId;
import 'program_widget_test.dart' show ProgramFixture;

class SaveThenReloadFailure extends DirectoryFixture {
  bool saved = false;
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'manage/profile') {
      saved = true;
      return {'id': profileId};
    }
    if (saved && path == 'manage') {
      throw const ApiFailure('Der neue Stand konnte nicht geladen werden.');
    }
    return super.directory(path, query: query, body: body);
  }
}

class DeniedProgram extends ProgramFixture {
  DeniedProgram() {
    hasGrant = true;
    allowed = true;
  }
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'manage/revoke' || path == 'manage/series') {
      throw const ApiFailure('Zugriff entzogen.', accessDenied: true);
    }
    return super.directory(path, query: query, body: body);
  }
}

class PendingProgram implements DirectoryApi {
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) => pending.future;
}

class WorkspaceFixture implements AccessFlowApi {
  bool unavailable = true;
  bool changed = false;
  final writes = <String>[];
  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (body != null) {
      writes.add(path);
      changed = true;
      return {'id': 'restriction'};
    }
    if (unavailable || changed) {
      throw const ApiFailure('Zuständigkeiten aktuell nicht verfügbar.');
    }
    return {
      'events': [
        {'id': 'event', 'title': 'Synthetic event'},
      ],
      'communities': [],
      'publisher_profiles': [],
      'publication_targets': [],
      'cases': [],
      'is_team': false,
    };
  }
}

class PendingFlowFixture extends FlowApi {
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> snapshot() => pending.future;
}

class RoleFlowFixture extends FlowApi {
  bool team = true;
  int snapshots = 0;
  @override
  Future<Map<String, dynamic>> snapshot() async {
    snapshots++;
    return {...await super.snapshot(), 'is_team': team};
  }

  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) async => {
    if (path == 'team')
      'applications': [
        {
          'id': 'application',
          'applicant': 'SYNTHETIC PRIVATE APPLICANT',
          'status': 'pending',
          'answers': <String, dynamic>{},
        },
      ],
  };
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profile save does not overwrite a failed refresh with success', (
    tester,
  ) async {
    final api = SaveThenReloadFailure();
    await tester.pumpWidget(
      MaterialApp(home: OrganizerManagementPage(api: api)),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Profil speichern'));
    expect(api.saved, isTrue);
    expect(find.text('Veranstalterprofil gespeichert.'), findsNothing);
    expect(
      find.text('Der neue Stand konnte nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('Profil speichern'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('program write denial removes private rows and grants', (
    tester,
  ) async {
    final api = DeniedProgram();
    await tester.pumpWidget(MaterialApp(home: ProgramManagementPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Demo Nebelreihe'), findsOneWidget);
    await tapVisible(tester, find.text('Sichtbarkeit entziehen'));
    expect(find.text('Zugriff entzogen.'), findsOneWidget);
    expect(find.text('Demo Nebelreihe'), findsNothing);
    expect(find.text('Demo Nebelabend'), findsNothing);
    expect(find.text('Sichtbarkeit entziehen'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old program response cannot replace a different profile', (
    tester,
  ) async {
    final old = PendingProgram();
    final current = ProgramFixture();
    Widget page(DirectoryApi api, String profile) => MaterialApp(
      home: ProgramManagementPage(
        key: const ValueKey('program'),
        api: api,
        profileId: profile,
      ),
    );
    await tester.pumpWidget(page(old, 'old-profile'));
    await tester.pump();
    await tester.pumpWidget(page(current, 'current-profile'));
    await tester.pumpAndSettle();
    old.pending.complete({
      'profile': {'id': 'old-profile'},
      'series': [
        {'id': 'old-series', 'title': 'OLD PRIVATE SERIES'},
      ],
      'events': [],
    });
    await tester.pumpAndSettle();
    expect(find.text('OLD PRIVATE SERIES'), findsNothing);
    expect(find.text('Demo Nebelreihe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old organizer response cannot replace a different profile', (
    tester,
  ) async {
    final old = PendingProgram();
    final current = DirectoryFixture();
    Widget page(DirectoryApi api, String profile) => MaterialApp(
      home: OrganizerManagementPage(
        key: const ValueKey('organizer'),
        api: api,
        initialProfileId: profile,
      ),
    );
    await tester.pumpWidget(page(old, 'old-profile'));
    await tester.pump();
    await tester.pumpWidget(page(current, 'current-profile'));
    await tester.pumpAndSettle();
    final previous = await DirectoryFixture().directory('manage');
    (previous['profile'] as Map)['name'] = 'OLD PRIVATE ORGANIZER';
    old.pending.complete(previous);
    await tester.pumpAndSettle();
    final values = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    expect(values, contains('Demo Kollektiv'));
    expect(values, isNot(contains('OLD PRIVATE ORGANIZER')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'series denial clears editable private content and offers return',
    (tester) async {
      final api = DeniedProgram();
      await tester.pumpWidget(
        MaterialApp(
          home: SeriesEditor(
            api: api,
            communities: api.communities,
            series: api.series.first,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Reihe speichern'));
      expect(find.text('Zugriff entzogen.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Zurück zur Verwaltung'), findsOneWidget);
      expect(find.text('Reihe speichern'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a series with an unavailable community requires a fresh valid choice',
    (tester) async {
      final api = DeniedProgram();
      await tester.pumpWidget(
        MaterialApp(
          home: SeriesEditor(
            api: api,
            communities: api.communities,
            series: {...api.series.first, 'community_id': 'removed-community'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reihe speichern'),
      );
      expect(button.onPressed, isNull);
      expect(
        find.textContaining('Bitte wähle eine verantwortliche Community'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo Musik').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Reihe speichern'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('access context change ignores a pending previous snapshot', (
    tester,
  ) async {
    final old = PendingFlowFixture();
    final current = RoleFlowFixture()..team = false;
    addTearDown(old.close);
    addTearDown(current.close);
    Widget page(AccessApi api) => MaterialApp(
      home: AccessFlowPage(key: const ValueKey('access'), api: api),
    );
    await tester.pumpWidget(page(old));
    await tester.pump();
    await tester.pumpWidget(page(current));
    await tester.pumpAndSettle();
    old.pending.complete({'is_team': true, 'moderated_communities': []});
    await tester.pumpAndSettle();
    expect(find.text('Teamprüfung'), findsNothing);
    expect(find.text('Persönliche Einladung'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moderation load has progress and a working retry', (
    tester,
  ) async {
    final api = WorkspaceFixture();
    await tester.pumpWidget(
      MaterialApp(home: PrivateAccessManagementPage(api: api)),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      find.text('Zuständigkeiten aktuell nicht verfügbar.'),
      findsOneWidget,
    );
    api.unavailable = false;
    await tapVisible(tester, find.text('Aktualisieren'));
    expect(find.text('Zuständigkeiten aktuell nicht verfügbar.'), findsNothing);
    expect(find.text('Bestätigte Konto-E-Mail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'moderation save preserves reload error instead of claiming success',
    (tester) async {
      final api = WorkspaceFixture()..unavailable = false;
      await tester.pumpWidget(
        MaterialApp(home: PrivateAccessManagementPage(api: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic event').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Eventzugang für 24 h sperren'));
      expect(api.writes, ['policy/restrictions']);
      expect(find.text('Vorgang gespeichert.'), findsNothing);
      expect(
        find.text('Zuständigkeiten aktuell nicht verfügbar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('access refresh reads once and clears a revoked team view', (
    tester,
  ) async {
    final api = RoleFlowFixture();
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: AccessFlowPage(api: api)));
    await tester.pumpAndSettle();
    expect(api.snapshots, 1);
    await tapVisible(tester, find.text('Teamprüfung'));
    expect(find.textContaining('SYNTHETIC PRIVATE APPLICANT'), findsOneWidget);
    final before = api.snapshots;
    api.team = false;
    await tester.tap(find.byTooltip('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(api.snapshots, before + 1);
    expect(find.textContaining('SYNTHETIC PRIVATE APPLICANT'), findsNothing);
    expect(find.text('Teamprüfung'), findsNothing);
    expect(find.text('Persönliche Einladung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
