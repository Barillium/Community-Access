import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_flow_api.dart';
import 'package:community_access_client/organizer_members_page.dart';

class MemberFixture implements AccessFlowApi {
  final bool owner;
  final bool mine;
  Completer<Map<String, dynamic>>? pending;
  final writes = <Map<String, dynamic>>[];
  String status = 'invited';
  int version = 1;
  MemberFixture({this.owner = false, this.mine = false});
  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (pending != null) return pending!.future;
    if (body != null) {
      writes.add({'path': path, ...body});
      status = path.endsWith('accept') ? 'active' : 'revoked';
      version++;
    }
    return {
      'is_owner': owner,
      'name': mine ? null : 'Synthetic collective',
      'items': [
        {
          'id': 'member',
          'profile_id': 'profile',
          'name': 'Synthetic colleague',
          'email': 'colleague@example.invalid',
          'status': status,
          'version': version,
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'invited account must explicitly accept, without owner controls',
    (tester) async {
      final api = MemberFixture(mine: true);
      await tester.pumpWidget(
        MaterialApp(home: OrganizerMembersPage(api: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zur gemeinsamen Verwaltung einladen'), findsNothing);
      expect(find.text('Verwaltung entziehen'), findsNothing);
      await tester.tap(find.text('Einladung zur Verwaltung annehmen'));
      await tester.pumpAndSettle();
      expect(
        api.writes.single['path'],
        'policy/organizer-members/member/accept',
      );
      expect(api.writes.single['version'], 1);
      expect(find.text('Verwaltung aktiv'), findsOneWidget);
    },
  );
  testWidgets('owner revokes the displayed member version at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = MemberFixture(owner: true);
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizerMembersPage(api: api, profileId: 'profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verwaltung entziehen'));
    await tester.pumpAndSettle();
    expect(api.writes.single['path'], 'policy/organizer-members/member/revoke');
    expect(api.writes.single['version'], 1);
    expect(find.text('Verwaltung entzogen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'late response from an old organizer cannot restore member data',
    (tester) async {
      final old = MemberFixture()..pending = Completer();
      final next = MemberFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizerMembersPage(
            key: const ValueKey('members'),
            api: old,
            profileId: 'old',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizerMembersPage(
            key: const ValueKey('members'),
            api: next,
            profileId: 'next',
          ),
        ),
      );
      await tester.pumpAndSettle();
      old.pending!.complete({'name': 'OLD PRIVATE COLLECTIVE', 'items': []});
      await tester.pumpAndSettle();
      expect(find.text('OLD PRIVATE COLLECTIVE'), findsNothing);
      expect(find.text('Synthetic collective'), findsOneWidget);
    },
  );
}
